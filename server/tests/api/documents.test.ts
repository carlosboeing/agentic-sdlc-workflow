/**
 * Tests for Document API routes (E06-S01).
 *
 * Covers:
 * - GET /api/documents — list markdown files in docs/ directory (recursive tree)
 * - GET /api/documents/:path — read a specific markdown file (with content)
 * - GET /api/documents/:path/comments — list comments for a document
 * - POST /api/documents/:path/comments — add comment with optional anchor
 *
 * Security:
 * - Path traversal prevention (../../../etc/passwd, /absolute/paths)
 * - Paths must be under docs/
 *
 * Document reading strategy:
 * - The server reads files from a configurable docsDir (defaults to repoRoot/docs/).
 * - Tests pass a temporary directory as docsDir so they are hermetic.
 */

import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createDocumentsRouter } from "../../src/api/documents";
import { createCommentsRouter } from "../../src/api/comments";
import { CommentService } from "../../src/services/comments";
import { DocumentService } from "../../src/services/documents";
import { setupTestDb } from "../helpers/setup-db";
import type { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";

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

  // Create a temporary docs directory for each test
  tmpDocsDir = join(tmpdir(), `wrs-docs-test-${Date.now()}`);
  mkdirSync(tmpDocsDir, { recursive: true });

  // Create some test markdown files
  writeFileSync(join(tmpDocsDir, "readme.md"), "# README\n\nHello world.\n");
  mkdirSync(join(tmpDocsDir, "design"), { recursive: true });
  writeFileSync(
    join(tmpDocsDir, "design", "overview.md"),
    "# Overview\n\nDesign overview.\n"
  );
  mkdirSync(join(tmpDocsDir, "guides"), { recursive: true });
  writeFileSync(
    join(tmpDocsDir, "guides", "getting-started.md"),
    "# Getting Started\n\nStep 1.\n"
  );
  // Non-markdown file — should NOT appear in listings
  writeFileSync(join(tmpDocsDir, "notes.txt"), "plain text file");

  app = buildApp(commentService, tmpDocsDir);
});

afterEach(() => {
  sqlite.close();
  // Clean up temporary directory
  rmSync(tmpDocsDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------------------
// GET /api/documents — list files
// ---------------------------------------------------------------------------

describe("GET /api/documents", () => {
  test("returns 200 with an array of file entries", async () => {
    const req = new Request("http://localhost/api/documents");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const body = (await res.json()) as unknown[];
    expect(Array.isArray(body)).toBe(true);
  });

  test("lists markdown files (not .txt files)", async () => {
    const req = new Request("http://localhost/api/documents");
    const res = await app.fetch(req);
    const body = (await res.json()) as AnyJson[];

    // Should contain readme.md but not notes.txt
    const paths = body.map((e) => e.path);
    expect(paths.some((p) => String(p).endsWith("readme.md"))).toBe(true);
    expect(paths.every((p) => String(p).endsWith(".txt") === false)).toBe(true);
  });

  test("includes nested files in subdirectories", async () => {
    const req = new Request("http://localhost/api/documents");
    const res = await app.fetch(req);
    const body = (await res.json()) as AnyJson[];
    const paths = body.map((e) => e.path);

    expect(paths.some((p) => String(p).includes("design/overview.md"))).toBe(true);
    expect(paths.some((p) => String(p).includes("guides/getting-started.md"))).toBe(true);
  });

  test("each entry has path and name fields", async () => {
    const req = new Request("http://localhost/api/documents");
    const res = await app.fetch(req);
    const body = (await res.json()) as AnyJson[];

    expect(body.length).toBeGreaterThan(0);
    for (const entry of body) {
      expect(typeof entry.path).toBe("string");
      expect(typeof entry.name).toBe("string");
    }
  });
});

// ---------------------------------------------------------------------------
// GET /api/documents/:path — read file
// ---------------------------------------------------------------------------

describe("GET /api/documents/:path", () => {
  test("returns 200 with file content for an existing file", async () => {
    const req = new Request("http://localhost/api/documents/readme.md");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const body = (await res.json()) as AnyJson;
    expect(body.path).toBe("readme.md");
    expect(typeof body.content).toBe("string");
    expect(String(body.content)).toContain("# README");
  });

  test("returns file in nested subdirectory", async () => {
    const req = new Request(
      "http://localhost/api/documents/design/overview.md"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const body = (await res.json()) as AnyJson;
    expect(body.path).toBe("design/overview.md");
    expect(String(body.content)).toContain("# Overview");
  });

  test("returns 404 for a non-existent file", async () => {
    const req = new Request(
      "http://localhost/api/documents/nonexistent.md"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(404);

    const body = (await res.json()) as AnyJson;
    expect(typeof body.error).toBe("string");
  });

  test("rejects path traversal with .. (returns 400)", async () => {
    const req = new Request(
      "http://localhost/api/documents/..%2F..%2Fetc%2Fpasswd"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });

  test("rejects encoded path traversal ../../../etc/passwd", async () => {
    const req = new Request(
      "http://localhost/api/documents/%2F%2Fetc%2Fpasswd"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });

  test("rejects absolute paths starting with /", async () => {
    // URL encoding: %2F = /, but the raw path would be /api/documents//etc/passwd
    // The path parameter itself should not start with /
    const req = new Request(
      "http://localhost/api/documents/%2Fetc%2Fpasswd"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });

  test("returns name field in response", async () => {
    const req = new Request("http://localhost/api/documents/readme.md");
    const res = await app.fetch(req);
    const body = (await res.json()) as AnyJson;
    expect(typeof body.name).toBe("string");
  });
});

// ---------------------------------------------------------------------------
// GET /api/documents/:path/comments — list document comments
// ---------------------------------------------------------------------------

describe("GET /api/documents/:path/comments", () => {
  test("returns 200 with empty array when no comments exist", async () => {
    const req = new Request(
      "http://localhost/api/documents/readme.md/comments"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const body = (await res.json()) as unknown[];
    expect(Array.isArray(body)).toBe(true);
    expect(body.length).toBe(0);
  });

  test("returns comments after one is added", async () => {
    // Add a comment directly via the service
    await commentService.addComment({
      documentPath: "readme.md",
      body: "Great document!",
      author: "reviewer",
    });

    const req = new Request(
      "http://localhost/api/documents/readme.md/comments"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const body = (await res.json()) as AnyJson[];
    expect(body.length).toBe(1);
    expect(body[0].body).toBe("Great document!");
    expect(body[0].author).toBe("reviewer");
  });

  test("rejects path traversal in comment list path (returns 400)", async () => {
    const req = new Request(
      "http://localhost/api/documents/..%2F..%2Fetc%2Fpasswd/comments"
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// POST /api/documents/:path/comments — add comment
// ---------------------------------------------------------------------------

describe("POST /api/documents/:path/comments", () => {
  test("creates a comment and returns 201", async () => {
    const req = new Request(
      "http://localhost/api/documents/readme.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          body: "This is a comment.",
          author: "human",
        }),
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(201);

    const comment = (await res.json()) as AnyJson;
    expect(comment.body).toBe("This is a comment.");
    expect(comment.author).toBe("human");
    // Drizzle returns camelCase: documentPath (column: document_path)
    expect(comment.documentPath).toBe("readme.md");
  });

  test("creates a comment with optional anchor", async () => {
    const req = new Request(
      "http://localhost/api/documents/readme.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          body: "Paragraph-anchored comment.",
          author: "reviewer",
          anchor: "section-overview",
        }),
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(201);

    const comment = (await res.json()) as AnyJson;
    expect(comment.anchor).toBe("section-overview");
  });

  test("returns 400 when body is missing", async () => {
    const req = new Request(
      "http://localhost/api/documents/readme.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ author: "human" }),
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });

  test("returns 400 when author is missing", async () => {
    const req = new Request(
      "http://localhost/api/documents/readme.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "comment text" }),
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });

  test("returns 400 when JSON body is invalid", async () => {
    const req = new Request(
      "http://localhost/api/documents/readme.md/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "not-json",
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });

  test("rejects path traversal on POST (returns 400)", async () => {
    const req = new Request(
      "http://localhost/api/documents/..%2Fetc%2Fpasswd/comments",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ body: "test", author: "human" }),
      }
    );
    const res = await app.fetch(req);
    expect(res.status).toBe(400);
  });
});

// ---------------------------------------------------------------------------
// DocumentService unit tests
// ---------------------------------------------------------------------------

describe("DocumentService", () => {
  test("listFiles returns only markdown files recursively", async () => {
    const svc = new DocumentService(tmpDocsDir);
    const files = await svc.listFiles();
    const paths = files.map((f) => f.path);
    expect(paths.some((p) => p === "readme.md")).toBe(true);
    expect(paths.some((p) => p === "design/overview.md")).toBe(true);
    expect(paths.some((p) => p === "guides/getting-started.md")).toBe(true);
    // .txt file must not be included
    expect(paths.every((p) => !p.endsWith(".txt"))).toBe(true);
  });

  test("readFile returns content for an existing file", async () => {
    const svc = new DocumentService(tmpDocsDir);
    const content = await svc.readFile("readme.md");
    expect(content).toContain("# README");
  });

  test("readFile returns null for non-existent file", async () => {
    const svc = new DocumentService(tmpDocsDir);
    const content = await svc.readFile("missing.md");
    expect(content).toBeNull();
  });

  test("isPathSafe rejects .. traversal", () => {
    const svc = new DocumentService(tmpDocsDir);
    expect(svc.isPathSafe("../../etc/passwd")).toBe(false);
    expect(svc.isPathSafe("../sibling")).toBe(false);
  });

  test("isPathSafe rejects absolute paths", () => {
    const svc = new DocumentService(tmpDocsDir);
    expect(svc.isPathSafe("/etc/passwd")).toBe(false);
    expect(svc.isPathSafe("/absolute/path.md")).toBe(false);
  });

  test("isPathSafe accepts simple relative paths", () => {
    const svc = new DocumentService(tmpDocsDir);
    expect(svc.isPathSafe("readme.md")).toBe(true);
    expect(svc.isPathSafe("design/overview.md")).toBe(true);
    expect(svc.isPathSafe("a/b/c/deep.md")).toBe(true);
  });
});
