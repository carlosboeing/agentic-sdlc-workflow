/**
 * End-to-end integration tests for the pull sync pipeline.
 *
 * Tests the full flow: GitHubPullFetcher -> IssueMapper -> DatabaseUpserter
 * -> PullSyncService, using an in-memory SQLite database and mocked _runGh()
 * calls to simulate GitHub GraphQL responses.
 *
 * DatabaseUpserter is passed directly to PullSyncService — no adapter needed
 * since both use the same field names (itemsCreated, itemsUpdated).
 */

import { describe, test, expect, beforeEach, afterEach, spyOn } from "bun:test";
import type { Database } from "bun:sqlite";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { eq } from "drizzle-orm";
import { setupTestDb } from "../helpers/setup-db";
import { GitHubPullFetcher } from "../../src/adapters/github-pull";
import { IssueMapper } from "../../src/lib/issue-mapper";
import { DatabaseUpserter } from "../../src/services/database-upserter";
import { PullSyncService } from "../../src/services/pull-sync";
import * as schema from "../../src/db/schema";

// ---------------------------------------------------------------------------
// Fixtures: GitHub GraphQL response shapes (matching design section 4.1)
// ---------------------------------------------------------------------------

/**
 * Build a full GitHub GraphQL page response as the gh CLI would return it.
 * Each issue node follows the exact query shape in design section 4.1.
 */
function makeGhPageResponse(
  issues: Array<{
    number: number;
    title: string;
    body?: string | null;
    state?: "OPEN" | "CLOSED";
    createdAt?: string;
    updatedAt?: string;
    url?: string;
    parent?: { number: number } | null;
    labels?: Array<{ name: string }>;
    projectItems?: Array<{
      fieldValues: {
        nodes: Array<{
          name: string;
          field: { name: string };
        }>;
      };
    }>;
    comments?: {
      totalCount: number;
      pageInfo: { hasNextPage: boolean; endCursor: string | null };
      nodes: Array<{
        body: string;
        author: { login: string } | null;
        createdAt: string;
        updatedAt: string;
      }>;
    };
  }>,
  hasNextPage: boolean,
  endCursor: string | null,
  totalCount?: number,
  rateLimitRemaining = 4500
): { stdout: string; stderr: string; exitCode: number } {
  const nodes = issues.map((i) => ({
    number: i.number,
    title: i.title,
    body: i.body ?? null,
    state: i.state ?? "OPEN",
    createdAt: i.createdAt ?? "2026-03-01T00:00:00Z",
    updatedAt: i.updatedAt ?? "2026-03-01T00:00:00Z",
    url: i.url ?? `https://github.com/carlosboeing/agentic-sdlc-workflow/issues/${i.number}`,
    parent: i.parent ?? null,
    labels: { nodes: i.labels ?? [] },
    projectItems: {
      nodes: (i.projectItems ?? []).map((pi) => ({
        fieldValues: pi.fieldValues,
      })),
    },
    comments: i.comments ?? {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  }));

  return {
    stdout: JSON.stringify({
      data: {
        repository: {
          issues: {
            totalCount: totalCount ?? issues.length,
            pageInfo: { hasNextPage, endCursor },
            nodes,
          },
        },
        rateLimit: {
          remaining: rateLimitRemaining,
          resetAt: "2026-03-01T01:00:00Z",
        },
      },
    }),
    stderr: "",
    exitCode: 0,
  };
}

/** Build a rate limit response (used by fetchRateLimit pre-flight). */
function makeRateLimitResponse(remaining = 4500): {
  stdout: string;
  stderr: string;
  exitCode: number;
} {
  return {
    stdout: JSON.stringify({
      data: { rateLimit: { remaining, resetAt: "2026-03-01T01:00:00Z" } },
    }),
    stderr: "",
    exitCode: 0,
  };
}

/** Build a comment page response (used by fetchCommentPage). */
function makeCommentPageResponse(
  comments: Array<{
    body: string;
    author: { login: string } | null;
    createdAt: string;
    updatedAt: string;
  }>,
  hasNextPage: boolean,
  endCursor: string | null
): { stdout: string; stderr: string; exitCode: number } {
  return {
    stdout: JSON.stringify({
      data: {
        repository: {
          issue: {
            comments: {
              pageInfo: { hasNextPage, endCursor },
              nodes: comments,
            },
          },
        },
      },
    }),
    stderr: "",
    exitCode: 0,
  };
}

// ---------------------------------------------------------------------------
// Test fixtures: realistic issue data
// ---------------------------------------------------------------------------

/** Page 1: backlog item + epic + two stories, all with various labels/status */
const PAGE_1_ISSUES = [
  {
    number: 1,
    title: "[#1] Calendar Tool Backlog",
    body: "Backlog item body. **Blocked by:** none",
    state: "OPEN" as const,
    createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-20T00:00:00Z",
    labels: [
      { name: "hierarchy/backlog" },
      { name: "backlog/1-calendar-tool" },
      { name: "size/M" },
    ],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "In Progress", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 2,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [
        {
          body: "Work started",
          author: { login: "orchestrator" },
          createdAt: "2026-01-10T00:00:00Z",
          updatedAt: "2026-01-10T00:00:00Z",
        },
        {
          body: "Telemetry: 30m 12s",
          author: { login: "orchestrator" },
          createdAt: "2026-01-20T00:00:00Z",
          updatedAt: "2026-01-20T00:00:00Z",
        },
      ],
    },
  },
  {
    number: 2,
    title: "[#1/E01] Core Calendar Feature",
    body: "Epic body. **Blocked by:** none",
    state: "OPEN" as const,
    createdAt: "2026-01-02T00:00:00Z",
    updatedAt: "2026-01-15T00:00:00Z",
    parent: { number: 1 },
    labels: [
      { name: "hierarchy/epic" },
      { name: "backlog/1-calendar-tool" },
    ],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "In Progress", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
  {
    number: 3,
    title: "[#1/E01-S01] Implement CalendarService",
    body: "Story body.",
    state: "CLOSED" as const,
    createdAt: "2026-01-03T00:00:00Z",
    updatedAt: "2026-01-12T00:00:00Z",
    parent: { number: 2 },
    labels: [
      { name: "hierarchy/story" },
      { name: "backlog/1-calendar-tool" },
      { name: "difficulty/medium" },
      { name: "type/feature" },
    ],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "Done", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 1,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [
        {
          body: "Ready for Review — branch e01-s01/implement-calendar-service",
          author: { login: "builder" },
          createdAt: "2026-01-12T00:00:00Z",
          updatedAt: "2026-01-12T00:00:00Z",
        },
      ],
    },
  },
  {
    number: 4,
    title: "[#1/E01-S02] Calendar API tests",
    body: "Story body with null author test.",
    state: "OPEN" as const,
    createdAt: "2026-01-04T00:00:00Z",
    updatedAt: "2026-01-14T00:00:00Z",
    parent: { number: 2 },
    labels: [
      { name: "hierarchy/story" },
      { name: "backlog/1-calendar-tool" },
      { name: "difficulty/easy" },
    ],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "In Review", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 1,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [
        {
          body: "Comment from deleted user",
          author: null,   // null author
          createdAt: "2026-01-14T00:00:00Z",
          updatedAt: "2026-01-14T00:00:00Z",
        },
      ],
    },
  },
  {
    number: 5,
    title: "[#1] Write design doc for Calendar Tool",
    body: "Design doc issue.",
    state: "CLOSED" as const,
    createdAt: "2026-01-01T01:00:00Z",
    updatedAt: "2026-01-05T00:00:00Z",
    parent: { number: 1 },
    labels: [
      { name: "type/docs" },
      { name: "backlog/1-calendar-tool" },
    ],
    projectItems: [],  // not on project board
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
];

/** Page 2: story in a different epic, unrelated issue, story not on board */
const PAGE_2_ISSUES = [
  {
    number: 6,
    title: "[#1/E02] Integration Epic",
    body: "Epic 2 body.",
    state: "OPEN" as const,
    createdAt: "2026-01-06T00:00:00Z",
    updatedAt: "2026-01-16T00:00:00Z",
    parent: { number: 1 },
    labels: [
      { name: "hierarchy/epic" },
      { name: "backlog/1-calendar-tool" },
    ],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "Ready", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
  {
    number: 7,
    title: "[#1/E02-S01] Integration tests",
    body: "Story 3 body.",
    state: "OPEN" as const,
    createdAt: "2026-01-07T00:00:00Z",
    updatedAt: "2026-01-17T00:00:00Z",
    parent: { number: 6 },
    labels: [
      { name: "hierarchy/story" },
      { name: "backlog/1-calendar-tool" },
      { name: "difficulty/easy" },
    ],
    projectItems: [],  // not on project board -> defaults to "backlog" status
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
  {
    number: 8,
    title: "Unrelated issue without hierarchy label",
    body: "Just a regular issue.",
    state: "OPEN" as const,
    createdAt: "2026-01-08T00:00:00Z",
    updatedAt: "2026-01-08T00:00:00Z",
    labels: [{ name: "type/bug" }],  // no hierarchy label -> defaults to "story"
    projectItems: [],
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
  {
    number: 9,
    title: "Backlog ready item",
    body: null,
    state: "OPEN" as const,
    createdAt: "2026-01-09T00:00:00Z",
    updatedAt: "2026-01-09T00:00:00Z",
    labels: [{ name: "hierarchy/backlog" }],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "Backlog", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
  {
    number: 10,
    title: "Done story",
    body: "A closed story.",
    state: "CLOSED" as const,
    createdAt: "2026-01-10T00:00:00Z",
    updatedAt: "2026-01-18T00:00:00Z",
    labels: [{ name: "hierarchy/story" }],
    projectItems: [
      {
        fieldValues: {
          nodes: [{ name: "Done", field: { name: "Status" } }],
        },
      },
    ],
    comments: {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  },
];

// ---------------------------------------------------------------------------
// Test suite setup helpers
// ---------------------------------------------------------------------------

function buildPipeline(db: ReturnType<typeof drizzle>) {
  const fetcher = new GitHubPullFetcher({ repo: "carlosboeing/agentic-sdlc-workflow" });
  const mapper = new IssueMapper();
  const upserter = new DatabaseUpserter(db);
  const service = new PullSyncService(fetcher as never, mapper, upserter);
  return { fetcher, mapper, upserter, service };
}

// ---------------------------------------------------------------------------
// Test: Full pipeline
// ---------------------------------------------------------------------------

describe("Pull sync integration: full pipeline", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("full pipeline: 2-page sync populates all items, labels, comments, and hierarchy", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    // Pre-flight rate limit + page 1 + page 2
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );

    const result = await service.pullSync();

    // Summary counts
    expect(result.totalIssues).toBe(10);
    expect(result.itemsCreated).toBe(10);
    expect(result.itemsUpdated).toBe(0);
    expect(result.errors).toEqual([]);

    // All 10 items persisted
    const allItems = db.select().from(schema.items).all();
    expect(allItems).toHaveLength(10);

    // Item 1: backlog, in-progress
    const item1 = allItems.find((i) => i.id === 1);
    expect(item1?.title).toBe("[#1] Calendar Tool Backlog");
    expect(item1?.type).toBe("backlog");
    expect(item1?.status).toBe("in-progress");
    expect(item1?.state).toBe("open");
    expect(item1?.externalId).toBe("1");
    expect(item1?.externalUrl).toContain("/issues/1");

    // Item 3: story, done, closed
    const item3 = allItems.find((i) => i.id === 3);
    expect(item3?.type).toBe("story");
    expect(item3?.status).toBe("done");
    expect(item3?.state).toBe("closed");

    // Item 5: docs type (type/docs label, no hierarchy)
    const item5 = allItems.find((i) => i.id === 5);
    expect(item5?.type).toBe("docs");
    expect(item5?.status).toBe("done");      // closed and not on board -> "done" fallback (issue-mapper)

    // Item 7: not on board -> default "backlog" status
    const item7 = allItems.find((i) => i.id === 7);
    expect(item7?.status).toBe("backlog");

    // Item 8: no hierarchy label -> defaults to "story"
    const item8 = allItems.find((i) => i.id === 8);
    expect(item8?.type).toBe("story");
  });

  test("full pipeline: labels are created and associated correctly", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );

    await service.pullSync();

    // Item 1 has 3 labels
    const item1Labels = db
      .select({ name: schema.labels.name })
      .from(schema.itemLabels)
      .innerJoin(schema.labels, eq(schema.itemLabels.labelId, schema.labels.id))
      .where(eq(schema.itemLabels.itemId, 1))
      .all();
    const item1LabelNames = item1Labels.map((l) => l.name);
    expect(item1LabelNames).toContain("hierarchy/backlog");
    expect(item1LabelNames).toContain("backlog/1-calendar-tool");
    expect(item1LabelNames).toContain("size/M");

    // Item 3 has 4 labels
    const item3Labels = db
      .select({ name: schema.labels.name })
      .from(schema.itemLabels)
      .innerJoin(schema.labels, eq(schema.itemLabels.labelId, schema.labels.id))
      .where(eq(schema.itemLabels.itemId, 3))
      .all();
    expect(item3Labels).toHaveLength(4);

    // Item 5 (not on board) has 2 labels
    const item5Labels = db
      .select({ name: schema.labels.name })
      .from(schema.itemLabels)
      .innerJoin(schema.labels, eq(schema.itemLabels.labelId, schema.labels.id))
      .where(eq(schema.itemLabels.itemId, 5))
      .all();
    expect(item5Labels).toHaveLength(2);
    expect(item5Labels.map((l) => l.name)).toContain("type/docs");
  });

  test("full pipeline: comments are inserted including null-author comment", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );

    await service.pullSync();

    // Item 1 has 2 comments
    const item1Comments = db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.itemId, 1))
      .all();
    expect(item1Comments).toHaveLength(2);

    // Item 4 has a comment with null author -> mapped to "unknown"
    const item4Comments = db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.itemId, 4))
      .all();
    expect(item4Comments).toHaveLength(1);
    expect(item4Comments[0].author).toBe("unknown");
    expect(item4Comments[0].body).toBe("Comment from deleted user");
  });

  test("full pipeline: parentId is set correctly via hierarchy linking pass", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );

    const result = await service.pullSync();
    expect(result.hierarchyLinked).toBeGreaterThan(0);

    const allItems = db.select().from(schema.items).all();
    const itemMap = Object.fromEntries(allItems.map((i) => [i.id, i]));

    // item 2 (epic) has parent 1 (backlog)
    expect(itemMap[2].parentId).toBe(1);
    // item 3 (story) has parent 2 (epic)
    expect(itemMap[3].parentId).toBe(2);
    // item 4 (story) has parent 2 (epic)
    expect(itemMap[4].parentId).toBe(2);
    // item 5 (docs) has parent 1
    expect(itemMap[5].parentId).toBe(1);
    // item 6 (epic) has parent 1
    expect(itemMap[6].parentId).toBe(1);
    // item 7 (story) has parent 6 (epic 2)
    expect(itemMap[7].parentId).toBe(6);
    // item 1 (root backlog) has no parent
    expect(itemMap[1].parentId).toBeNull();
    // item 8 (no parent in fixture) has no parent
    expect(itemMap[8].parentId).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Test: Idempotency
// ---------------------------------------------------------------------------

describe("Pull sync integration: idempotency", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("running pullSync() twice with same data produces identical row counts", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    // First run
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );
    await service.pullSync();

    // Capture row counts after first sync
    const itemsAfterFirst = db.select().from(schema.items).all().length;
    const labelsAfterFirst = db.select().from(schema.labels).all().length;
    const itemLabelsAfterFirst = db.select().from(schema.itemLabels).all().length;
    const commentsAfterFirst = db.select().from(schema.comments).all().length;

    // Second run — identical data
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );
    const secondResult = await service.pullSync();

    // Row counts must be identical (no duplicates)
    expect(db.select().from(schema.items).all()).toHaveLength(itemsAfterFirst);
    expect(db.select().from(schema.labels).all()).toHaveLength(labelsAfterFirst);
    expect(db.select().from(schema.itemLabels).all()).toHaveLength(itemLabelsAfterFirst);
    expect(db.select().from(schema.comments).all()).toHaveLength(commentsAfterFirst);

    // Second sync reports all items updated (0 new)
    expect(secondResult.itemsCreated).toBe(0);
    expect(secondResult.itemsUpdated).toBe(10);
  });
});

// ---------------------------------------------------------------------------
// Test: Partial sync recovery
// ---------------------------------------------------------------------------

describe("Pull sync integration: partial sync recovery", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("after partial sync (page 1 then rate limit abort), second sync completes all items", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    // First attempt: page 1 succeeds, then fetchAllPages throws rate limit error
    // Simulate by having the second page return rate-limit-exhausted remaining
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));  // pre-flight
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10, 490)  // remaining=490 < 500 → abort after yield
    );

    await expect(service.pullSync()).rejects.toThrow(/rate limit/i);

    // Only page 1 items should be in the DB (5 items)
    const partialItems = db.select().from(schema.items).all();
    expect(partialItems).toHaveLength(5);

    // Second attempt: full sync completes
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));  // pre-flight
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_1_ISSUES, true, "cursor_after_5", 10)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(PAGE_2_ISSUES, false, null, 10)
    );

    const recoveryResult = await service.pullSync();
    expect(recoveryResult.errors).toEqual([]);

    // All 10 items present
    const allItems = db.select().from(schema.items).all();
    expect(allItems).toHaveLength(10);

    // The 5 from page 1 were updated; the 5 from page 2 were created
    expect(recoveryResult.itemsCreated).toBe(5);
    expect(recoveryResult.itemsUpdated).toBe(5);

    // Hierarchy linked for all child items
    const allItemMap = Object.fromEntries(allItems.map((i) => [i.id, i]));
    expect(allItemMap[2].parentId).toBe(1);
    expect(allItemMap[7].parentId).toBe(6);
  });
});

// ---------------------------------------------------------------------------
// Test: Label reconciliation
// ---------------------------------------------------------------------------

describe("Pull sync integration: label reconciliation", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("second sync with changed labels [A,B] -> [B,C] produces only [B,C] in item_labels", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    const issueV1 = [{
      number: 100,
      title: "Label reconciliation issue",
      labels: [{ name: "label-A" }, { name: "label-B" }],
    }];
    const issueV2 = [{
      number: 100,
      title: "Label reconciliation issue",
      labels: [{ name: "label-B" }, { name: "label-C" }],
    }];

    // First sync: labels [A, B]
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(issueV1, false, null, 1)
    );

    await service.pullSync();

    // Verify [A, B] are associated
    const afterFirst = db
      .select({ name: schema.labels.name })
      .from(schema.itemLabels)
      .innerJoin(schema.labels, eq(schema.itemLabels.labelId, schema.labels.id))
      .where(eq(schema.itemLabels.itemId, 100))
      .all()
      .map((l) => l.name);
    expect(afterFirst.sort()).toEqual(["label-A", "label-B"]);

    // Second sync: labels [B, C]
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(issueV2, false, null, 1)
    );

    await service.pullSync();

    // Verify only [B, C] remain in item_labels
    const afterSecond = db
      .select({ name: schema.labels.name })
      .from(schema.itemLabels)
      .innerJoin(schema.labels, eq(schema.itemLabels.labelId, schema.labels.id))
      .where(eq(schema.itemLabels.itemId, 100))
      .all()
      .map((l) => l.name);
    expect(afterSecond.sort()).toEqual(["label-B", "label-C"]);

    // label-A row still exists in labels table (deferred cleanup), but NOT in item_labels
    const labelARow = db
      .select()
      .from(schema.labels)
      .where(eq(schema.labels.name, "label-A"))
      .all();
    expect(labelARow).toHaveLength(1);

    const labelAAssociation = db
      .select()
      .from(schema.itemLabels)
      .where(eq(schema.itemLabels.itemId, 100))
      .all();
    // Only 2 associations remain
    expect(labelAAssociation).toHaveLength(2);
  });
});

// ---------------------------------------------------------------------------
// Test: Hierarchy across pages
// ---------------------------------------------------------------------------

describe("Pull sync integration: hierarchy across page boundaries", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("parent on page 1 and child on page 2 are linked correctly", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    // Parent (backlog) on page 1, children (epics/stories) on page 2
    const page1 = [
      {
        number: 200,
        title: "Parent Backlog Item",
        labels: [{ name: "hierarchy/backlog" }],
        projectItems: [
          { fieldValues: { nodes: [{ name: "In Progress", field: { name: "Status" } }] } },
        ],
      },
    ];
    const page2 = [
      {
        number: 201,
        title: "Child Epic",
        parent: { number: 200 },
        labels: [{ name: "hierarchy/epic" }],
        projectItems: [
          { fieldValues: { nodes: [{ name: "In Progress", field: { name: "Status" } }] } },
        ],
      },
      {
        number: 202,
        title: "Child Story",
        parent: { number: 201 },
        labels: [{ name: "hierarchy/story" }],
        projectItems: [],
      },
    ];

    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(page1, true, "cursor_after_1", 3)
    );
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(page2, false, null, 3)
    );

    const result = await service.pullSync();
    expect(result.hierarchyLinked).toBe(2);

    const items = db.select().from(schema.items).all();
    const itemMap = Object.fromEntries(items.map((i) => [i.id, i]));

    expect(itemMap[201].parentId).toBe(200);
    expect(itemMap[202].parentId).toBe(201);
    expect(itemMap[200].parentId).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Test: Comment update
// ---------------------------------------------------------------------------

describe("Pull sync integration: comment update", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("second sync updates comment body when createdAt and author are unchanged", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    const issueV1 = [{
      number: 300,
      title: "Comment update issue",
      labels: [{ name: "hierarchy/story" }],
      comments: {
        totalCount: 1,
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [{
          body: "version 1",
          author: { login: "alice" },
          createdAt: "2026-03-01T10:00:00Z",
          updatedAt: "2026-03-01T10:00:00Z",
        }],
      },
    }];

    const issueV2 = [{
      number: 300,
      title: "Comment update issue",
      labels: [{ name: "hierarchy/story" }],
      comments: {
        totalCount: 1,
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [{
          body: "version 2",
          author: { login: "alice" },
          createdAt: "2026-03-01T10:00:00Z",  // same createdAt (dedup key)
          updatedAt: "2026-03-01T11:00:00Z",  // updatedAt changed (edited)
        }],
      },
    }];

    // First sync
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(makeGhPageResponse(issueV1, false, null, 1));
    await service.pullSync();

    // Verify version 1 is stored
    const beforeUpdate = db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.itemId, 300))
      .all();
    expect(beforeUpdate).toHaveLength(1);
    expect(beforeUpdate[0].body).toBe("version 1");

    // Second sync — same comment, updated body
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(makeGhPageResponse(issueV2, false, null, 1));
    const result = await service.pullSync();

    // Comment was updated, not duplicated
    expect(result.commentsCreated).toBe(0);
    expect(result.commentsUpdated).toBe(1);

    const afterUpdate = db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.itemId, 300))
      .all();
    expect(afterUpdate).toHaveLength(1);
    expect(afterUpdate[0].body).toBe("version 2");
    expect(afterUpdate[0].updatedAt).toBe("2026-03-01T11:00:00Z");
  });
});

// ---------------------------------------------------------------------------
// Test: Comment overflow pagination
// ---------------------------------------------------------------------------

describe("Pull sync integration: comment overflow pagination", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    const conn = setupTestDb();
    sqlite = conn.sqlite;
    db = conn.db;
  });

  afterEach(() => {
    sqlite.close();
  });

  test("overflow comments (hasNextPage=true) are fetched and stored in database", async () => {
    const { fetcher, service } = buildPipeline(db);
    const runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");

    // Issue with 52 comments (50 in first page, 2 in overflow).
    // Each comment gets a unique createdAt to avoid dedup collisions.
    const firstPageComments = Array.from({ length: 50 }, (_, i) => ({
      body: `Comment ${i + 1}`,
      author: { login: "user" },
      createdAt: `2026-03-01T${String(Math.floor(i / 60)).padStart(2, "0")}:${String(i % 60).padStart(2, "0")}:00Z`,
      updatedAt: `2026-03-01T${String(Math.floor(i / 60)).padStart(2, "0")}:${String(i % 60).padStart(2, "0")}:00Z`,
    }));

    const overflowComments = [
      {
        body: "Comment 51",
        author: { login: "user" },
        createdAt: "2026-03-04T02:00:00Z",
        updatedAt: "2026-03-04T02:00:00Z",
      },
      {
        body: "Comment 52",
        author: { login: "user" },
        createdAt: "2026-03-04T03:00:00Z",
        updatedAt: "2026-03-04T03:00:00Z",
      },
    ];

    const issueWithOverflow = [{
      number: 400,
      title: "Heavy issue with many comments",
      labels: [{ name: "hierarchy/backlog" }],
      comments: {
        totalCount: 52,
        pageInfo: { hasNextPage: true, endCursor: "cursor_after_50" },
        nodes: firstPageComments,
      },
    }];

    // Rate limit + main page + overflow comment page
    runGhSpy.mockResolvedValueOnce(makeRateLimitResponse(4500));
    runGhSpy.mockResolvedValueOnce(
      makeGhPageResponse(issueWithOverflow, false, null, 1)
    );
    runGhSpy.mockResolvedValueOnce(
      makeCommentPageResponse(overflowComments, false, null)
    );

    await service.pullSync();

    // All 52 comments should be in the database
    const allComments = db
      .select()
      .from(schema.comments)
      .where(eq(schema.comments.itemId, 400))
      .all();
    expect(allComments).toHaveLength(52);

    // Verify the overflow comments are present
    const overflowBodies = allComments.map((c) => c.body);
    expect(overflowBodies).toContain("Comment 51");
    expect(overflowBodies).toContain("Comment 52");
  });
});
