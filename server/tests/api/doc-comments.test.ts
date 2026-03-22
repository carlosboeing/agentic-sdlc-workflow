/**
 * Tests for Document Comment Threads and Paragraph Anchoring (E06-S02).
 *
 * Covers:
 * - GET /api/documents/:path/comments — returns all comments for a document
 * - POST /api/documents/:path/comments — creates comment with anchor and thread_id
 * - Anchor generation: slugified headings, sequential paragraph indices
 * - Thread replies: comments with thread_id pointing to parent
 * - Stale anchor detection: comments with anchors not present in document
 * - Comment grouping by anchor
 */

import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createDocumentsRouter } from "../../src/api/documents";
import { CommentService } from "../../src/services/comments";
import { DocumentService } from "../../src/services/documents";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { slugifyHeading, generateParagraphAnchors } from "../../src/lib/anchors";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

type AnyJson = Record<string, unknown>;
type Db = ReturnType<typeof drizzle>;

function buildApp(commentService: CommentService, docsDir: string): Hono {
  const app = new Hono();
  const documentService = new DocumentService(docsDir);
  app.route("/api", createDocumentsRouter(documentService, commentService));
  app.onError((err, c) => {
    console.error(err);
    return c.json({ error: "Internal server error" }, 500);
  });
  return app;
}

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

let sqlite: Database;
let db: Db;
let commentService: CommentService;
let tmpDocsDir: string;
let app: Hono;

beforeEach(() => {
  const setup = setupTestDb();
  sqlite = setup.sqlite;
  db = setup.db;
  commentService = new CommentService(db);

  tmpDocsDir = join(tmpdir(), `wrs-doc-comments-test-${Date.now()}`);
  mkdirSync(tmpDocsDir, { recursive: true });

  // Create test markdown with headings and paragraphs
  writeFileSync(
    join(tmpDocsDir, "test-doc.md"),
    `# Introduction

This is the first paragraph of the introduction.

This is the second paragraph.

## Design Decisions

The system uses SQLite for persistence.

### Performance Notes

Benchmarks show acceptable latency.
`
  );

  app = buildApp(commentService, tmpDocsDir);
});

afterEach(() => {
  sqlite.close();
  rmSync(tmpDocsDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------------------
// Anchor generation (pure logic)
// ---------------------------------------------------------------------------

describe("slugifyHeading", () => {
  test("converts heading text to lowercase slug", () => {
    expect(slugifyHeading("Introduction")).toBe("introduction");
  });

  test("replaces spaces with hyphens", () => {
    expect(slugifyHeading("Design Decisions")).toBe("design-decisions");
  });

  test("removes special characters", () => {
    expect(slugifyHeading("What's New?")).toBe("whats-new");
  });

  test("collapses multiple hyphens", () => {
    expect(slugifyHeading("A -- B --- C")).toBe("a-b-c");
  });

  test("trims leading and trailing hyphens", () => {
    expect(slugifyHeading("--hello--")).toBe("hello");
  });

  test("handles empty string", () => {
    expect(slugifyHeading("")).toBe("");
  });

  test("handles numbers in heading", () => {
    expect(slugifyHeading("Step 1: Setup")).toBe("step-1-setup");
  });
});

describe("generateParagraphAnchors", () => {
  test("assigns slugified IDs to headings", () => {
    const md = `# Introduction\n\nSome text.\n\n## Design\n\nMore text.\n`;
    const anchors = generateParagraphAnchors(md);

    // First element: h1 heading
    expect(anchors[0]).toEqual({ type: "heading", anchor: "introduction", level: 1 });
    // Third element: h2 heading
    const designAnchor = anchors.find(a => a.anchor === "design");
    expect(designAnchor).toBeDefined();
    expect(designAnchor!.type).toBe("heading");
    expect(designAnchor!.level).toBe(2);
  });

  test("assigns sequential indices to paragraphs", () => {
    const md = `# Title\n\nFirst paragraph.\n\nSecond paragraph.\n\nThird paragraph.\n`;
    const anchors = generateParagraphAnchors(md);

    const paragraphs = anchors.filter(a => a.type === "paragraph");
    expect(paragraphs.length).toBe(3);
    expect(paragraphs[0].anchor).toBe("p-0");
    expect(paragraphs[1].anchor).toBe("p-1");
    expect(paragraphs[2].anchor).toBe("p-2");
  });

  test("handles mixed headings and paragraphs", () => {
    const md = `# Intro\n\nParagraph one.\n\n## Section\n\nParagraph two.\n`;
    const anchors = generateParagraphAnchors(md);

    expect(anchors.length).toBe(4);
    expect(anchors[0]).toEqual({ type: "heading", anchor: "intro", level: 1 });
    expect(anchors[1]).toEqual({ type: "paragraph", anchor: "p-0" });
    expect(anchors[2]).toEqual({ type: "heading", anchor: "section", level: 2 });
    expect(anchors[3]).toEqual({ type: "paragraph", anchor: "p-1" });
  });

  test("handles h3 through h6 headings", () => {
    const md = `### Sub Section\n\n#### Deep\n\n##### Deeper\n\n###### Deepest\n`;
    const anchors = generateParagraphAnchors(md);

    expect(anchors[0]).toEqual({ type: "heading", anchor: "sub-section", level: 3 });
    expect(anchors[1]).toEqual({ type: "heading", anchor: "deep", level: 4 });
    expect(anchors[2]).toEqual({ type: "heading", anchor: "deeper", level: 5 });
    expect(anchors[3]).toEqual({ type: "heading", anchor: "deepest", level: 6 });
  });

  test("returns empty array for empty content", () => {
    expect(generateParagraphAnchors("")).toEqual([]);
  });

  test("handles document with only headings", () => {
    const md = `# One\n\n## Two\n\n### Three\n`;
    const anchors = generateParagraphAnchors(md);
    expect(anchors.every(a => a.type === "heading")).toBe(true);
    expect(anchors.length).toBe(3);
  });

  test("handles document with only paragraphs", () => {
    const md = `First.\n\nSecond.\n\nThird.\n`;
    const anchors = generateParagraphAnchors(md);
    expect(anchors.every(a => a.type === "paragraph")).toBe(true);
    expect(anchors.length).toBe(3);
    expect(anchors[0].anchor).toBe("p-0");
  });
});

// ---------------------------------------------------------------------------
// POST /api/documents/:path/comments with thread_id
// ---------------------------------------------------------------------------

describe("POST /api/documents/:path/comments — thread support", () => {
  test("creates a comment with thread_id field", async () => {
    // First create parent comment
    const parentReq = new Request(
      "http://localhost/api/documents/test-doc.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          body: "Parent comment",
          author: "reviewer",
          anchor: "introduction",
        }),
      }
    );
    const parentRes = await app.fetch(parentReq);
    expect(parentRes.status).toBe(201);
    const parent = (await parentRes.json()) as AnyJson;

    // Create reply with thread_id
    const replyReq = new Request(
      "http://localhost/api/documents/test-doc.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          body: "Reply to parent",
          author: "builder",
          anchor: "introduction",
          thread_id: String(parent.id),
        }),
      }
    );
    const replyRes = await app.fetch(replyReq);
    expect(replyRes.status).toBe(201);

    const reply = (await replyRes.json()) as AnyJson;
    expect(reply.body).toBe("Reply to parent");
    expect(reply.author).toBe("builder");
    expect(reply.threadId).toBe(String(parent.id));
  });

  test("creates a comment without thread_id (top-level)", async () => {
    const req = new Request(
      "http://localhost/api/documents/test-doc.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          body: "Top-level comment",
          author: "human",
          anchor: "design-decisions",
        }),
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(201);

    const comment = (await res.json()) as AnyJson;
    expect(comment.threadId).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// GET /api/documents/:path/comments — listing with anchors and threads
// ---------------------------------------------------------------------------

describe("GET /api/documents/:path/comments — with anchors and threads", () => {
  test("returns comments grouped by anchor when anchor field is present", async () => {
    // Add comments on different anchors
    await commentService.addComment({
      documentPath: "test-doc.md",
      body: "Comment on intro",
      author: "reviewer",
      anchor: "introduction",
    });
    await commentService.addComment({
      documentPath: "test-doc.md",
      body: "Comment on design",
      author: "builder",
      anchor: "design-decisions",
    });
    await commentService.addComment({
      documentPath: "test-doc.md",
      body: "Another on intro",
      author: "human",
      anchor: "introduction",
    });

    const req = new Request(
      "http://localhost/api/documents/test-doc.md/comments"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const comments = (await res.json()) as AnyJson[];
    expect(comments.length).toBe(3);

    // Verify anchors are preserved
    const introComments = comments.filter(
      (c) => c.anchor === "introduction"
    );
    expect(introComments.length).toBe(2);

    const designComments = comments.filter(
      (c) => c.anchor === "design-decisions"
    );
    expect(designComments.length).toBe(1);
  });

  test("returns thread replies alongside parent comments", async () => {
    // Create parent
    const parent = await commentService.addComment({
      documentPath: "test-doc.md",
      body: "Parent thread",
      author: "reviewer",
      anchor: "introduction",
    });

    // Create replies
    await commentService.addComment({
      documentPath: "test-doc.md",
      body: "Reply 1",
      author: "builder",
      anchor: "introduction",
      threadId: String(parent.id),
    });
    await commentService.addComment({
      documentPath: "test-doc.md",
      body: "Reply 2",
      author: "human",
      anchor: "introduction",
      threadId: String(parent.id),
    });

    const req = new Request(
      "http://localhost/api/documents/test-doc.md/comments"
    );
    const res = await app.fetch(req);
    const comments = (await res.json()) as AnyJson[];

    expect(comments.length).toBe(3);

    const replies = comments.filter(
      (c) => c.threadId === String(parent.id)
    );
    expect(replies.length).toBe(2);
  });

  test("does not return comments from other documents", async () => {
    await commentService.addComment({
      documentPath: "test-doc.md",
      body: "On test-doc",
      author: "reviewer",
      anchor: "introduction",
    });
    await commentService.addComment({
      documentPath: "other-doc.md",
      body: "On other-doc",
      author: "builder",
      anchor: "overview",
    });

    const req = new Request(
      "http://localhost/api/documents/test-doc.md/comments"
    );
    const res = await app.fetch(req);
    const comments = (await res.json()) as AnyJson[];

    expect(comments.length).toBe(1);
    expect(comments[0].body).toBe("On test-doc");
  });
});

// ---------------------------------------------------------------------------
// Stale anchor detection
// ---------------------------------------------------------------------------

describe("stale anchor detection", () => {
  test("identifies comments with anchors not in the document", () => {
    const documentAnchors = ["introduction", "p-0", "design-decisions", "p-1"];
    const comments = [
      { anchor: "introduction" },
      { anchor: "old-section-removed" },
      { anchor: "p-0" },
      { anchor: "nonexistent-heading" },
      { anchor: null }, // no anchor — not stale
    ];

    const stale = comments.filter(
      (c) => c.anchor !== null && !documentAnchors.includes(c.anchor)
    );
    expect(stale.length).toBe(2);
    expect(stale.map((c) => c.anchor)).toEqual([
      "old-section-removed",
      "nonexistent-heading",
    ]);
  });
});
