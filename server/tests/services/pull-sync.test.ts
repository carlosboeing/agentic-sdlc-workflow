import { describe, test, expect, beforeEach, mock, spyOn } from "bun:test";
import type { GitHubIssuePage, GitHubRateLimitResponse } from "../../src/adapters/github-pull";
import {
  PullSyncService,
  type PullSyncOptions,
  type PullSyncResult,
} from "../../src/services/pull-sync";

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

/** Creates a minimal GitHubIssuePage fixture. */
function makeIssuePage(
  count: number,
  startNumber = 1,
  hasNextPage = false,
  endCursor: string | null = null,
  rateLimitRemaining = 4500
): GitHubIssuePage {
  return {
    totalCount: count,
    pageInfo: { hasNextPage, endCursor },
    rateLimitRemaining,
    nodes: Array.from({ length: count }, (_, i) => ({
      number: startNumber + i,
      title: `Issue ${startNumber + i}`,
      body: "body",
      state: "OPEN" as const,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      url: `https://github.com/owner/repo/issues/${startNumber + i}`,
      parent: null,
      labels: { nodes: [] },
      projectItems: { nodes: [] },
      comments: {
        totalCount: 0,
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [],
      },
    })),
  };
}

/** Creates a mock IssueMapper. */
function makeMockMapper() {
  return {
    mapIssue: mock((issue: unknown) => ({
      item: {
        id: (issue as { number: number }).number,
        title: `Issue ${(issue as { number: number }).number}`,
        body: null,
        type: "story" as const,
        status: "backlog" as const,
        state: "open" as const,
        externalId: String((issue as { number: number }).number),
        externalUrl: `https://github.com/owner/repo/issues/${(issue as { number: number }).number}`,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z",
      },
      labels: [],
      parentNumber: null,
      comments: [],
    })),
  };
}

/** Creates a mock DatabaseUpserter. */
function makeMockUpserter() {
  return {
    upsertPage: mock(() => ({ created: 0, updated: 0, labelsCreated: 0, commentsCreated: 0, commentsUpdated: 0 })),
    linkHierarchy: mock(() => 0),
  };
}

/** Creates a mock GitHubPullFetcher. */
function makeMockFetcher(pages: GitHubIssuePage[]) {
  let callIndex = 0;
  const allPages = [...pages];

  return {
    fetchRateLimit: mock(
      async (): Promise<GitHubRateLimitResponse> => ({
        remaining: 4500,
        resetAt: "2026-01-01T01:00:00Z",
      })
    ),
    fetchAllPages: mock(async function* () {
      for (const page of allPages) {
        yield page;
        callIndex++;
      }
    }),
    fetchCommentPage: mock(async () => ({
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    })),
  };
}

/** Creates a mock EventService. */
function makeMockEventService() {
  return {
    broadcast: mock(() => {}),
  };
}

// ---------------------------------------------------------------------------
// PullSyncService.pullSync
// ---------------------------------------------------------------------------

describe("PullSyncService.pullSync", () => {
  let mapper: ReturnType<typeof makeMockMapper>;
  let upserter: ReturnType<typeof makeMockUpserter>;
  let eventService: ReturnType<typeof makeMockEventService>;

  beforeEach(() => {
    mapper = makeMockMapper();
    upserter = makeMockUpserter();
    eventService = makeMockEventService();
  });

  test("returns PullSyncResult with populated counters after single page", async () => {
    const fetcher = makeMockFetcher([makeIssuePage(3)]);
    upserter.upsertPage.mockReturnValue({ created: 2, updated: 1, labelsCreated: 0, commentsCreated: 0, commentsUpdated: 0 });
    upserter.linkHierarchy.mockReturnValue(2);

    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    const result = await service.pullSync();

    expect(result.totalIssues).toBe(3);
    expect(result.itemsCreated).toBe(2);
    expect(result.itemsUpdated).toBe(1);
    expect(result.hierarchyLinked).toBe(2);
    expect(result.errors).toEqual([]);
    expect(typeof result.durationMs).toBe("number");
    expect(result.durationMs).toBeGreaterThanOrEqual(0);
  });

  test("aggregates counters across multiple pages", async () => {
    const pages = [
      makeIssuePage(2, 1, true, "cursor1"),
      makeIssuePage(2, 3, true, "cursor2"),
      makeIssuePage(2, 5, false, null),
    ];
    const fetcher = makeMockFetcher(pages);
    upserter.upsertPage
      .mockReturnValueOnce({ created: 2, updated: 0, labelsCreated: 1, commentsCreated: 5, commentsUpdated: 0 })
      .mockReturnValueOnce({ created: 1, updated: 1, labelsCreated: 0, commentsCreated: 3, commentsUpdated: 1 })
      .mockReturnValueOnce({ created: 0, updated: 2, labelsCreated: 2, commentsCreated: 0, commentsUpdated: 2 });
    upserter.linkHierarchy.mockReturnValue(4);

    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    const result = await service.pullSync();

    // totalIssues from first page totalCount
    expect(result.totalIssues).toBe(2);
    expect(result.itemsCreated).toBe(3); // 2+1+0
    expect(result.itemsUpdated).toBe(3); // 0+1+2
    expect(result.labelsCreated).toBe(3); // 1+0+2
    expect(result.commentsCreated).toBe(8); // 5+3+0
    expect(result.commentsUpdated).toBe(3); // 0+1+2
    expect(result.hierarchyLinked).toBe(4);
  });

  test("calls mapper.mapIssue for each issue node", async () => {
    const fetcher = makeMockFetcher([makeIssuePage(3)]);
    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    await service.pullSync();

    expect(mapper.mapIssue.mock.calls.length).toBe(3);
  });

  test("calls upserter.upsertPage once per page", async () => {
    const pages = [
      makeIssuePage(2, 1, true, "c1"),
      makeIssuePage(2, 3, false, null),
    ];
    const fetcher = makeMockFetcher(pages);
    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    await service.pullSync();

    expect(upserter.upsertPage.mock.calls.length).toBe(2);
  });

  test("calls upserter.linkHierarchy once after all pages", async () => {
    const pages = [
      makeIssuePage(2, 1, true, "c1"),
      makeIssuePage(2, 3, false, null),
    ];
    const fetcher = makeMockFetcher(pages);
    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    await service.pullSync();

    expect(upserter.linkHierarchy.mock.calls.length).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// PullSyncService event emission
// ---------------------------------------------------------------------------

describe("PullSyncService event emission", () => {
  test("emits sync:pull:started after first page", async () => {
    const fetcher = makeMockFetcher([makeIssuePage(2)]);
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();
    const eventService = makeMockEventService();

    const service = new PullSyncService(
      fetcher as never,
      mapper as never,
      upserter as never,
      eventService as never
    );
    await service.pullSync();

    const broadcastCalls = eventService.broadcast.mock.calls as Array<[{ type: string; data: unknown }]>;
    const startedCall = broadcastCalls.find(([msg]) => msg.type === "sync:pull:started");
    expect(startedCall).toBeDefined();
  });

  test("emits sync:pull:progress after each page", async () => {
    const pages = [
      makeIssuePage(2, 1, true, "c1"),
      makeIssuePage(2, 3, false, null),
    ];
    const fetcher = makeMockFetcher(pages);
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();
    const eventService = makeMockEventService();

    const service = new PullSyncService(
      fetcher as never,
      mapper as never,
      upserter as never,
      eventService as never
    );
    await service.pullSync();

    const broadcastCalls = eventService.broadcast.mock.calls as Array<[{ type: string; data: unknown }]>;
    const progressCalls = broadcastCalls.filter(([msg]) => msg.type === "sync:pull:progress");
    // One progress event per page
    expect(progressCalls.length).toBe(2);
  });

  test("emits sync:pull:complete with result at end", async () => {
    const fetcher = makeMockFetcher([makeIssuePage(5)]);
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();
    upserter.upsertPage.mockReturnValue({ created: 3, updated: 2, labelsCreated: 0, commentsCreated: 0, commentsUpdated: 0 });
    const eventService = makeMockEventService();

    const service = new PullSyncService(
      fetcher as never,
      mapper as never,
      upserter as never,
      eventService as never
    );
    await service.pullSync();

    const broadcastCalls = eventService.broadcast.mock.calls as Array<[{ type: string; data: unknown }]>;
    const completedCall = broadcastCalls.find(([msg]) => msg.type === "sync:pull:complete");
    expect(completedCall).toBeDefined();
    const data = completedCall![0].data as PullSyncResult;
    expect(data.totalIssues).toBe(5);
  });

  test("emits sync:pull:error on failure", async () => {
    const fetcher = {
      fetchRateLimit: mock(async (): Promise<GitHubRateLimitResponse> => ({
        remaining: 4500,
        resetAt: "2026-01-01T01:00:00Z",
      })),
      fetchAllPages: mock(async function* () {
        throw new Error("Simulated network failure");
      }),
      fetchCommentPage: mock(async () => ({
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [],
      })),
    };
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();
    const eventService = makeMockEventService();

    const service = new PullSyncService(
      fetcher as never,
      mapper as never,
      upserter as never,
      eventService as never
    );

    await expect(service.pullSync()).rejects.toThrow("Simulated network failure");

    const broadcastCalls = eventService.broadcast.mock.calls as Array<[{ type: string; data: unknown }]>;
    const errorCall = broadcastCalls.find(([msg]) => msg.type === "sync:pull:error");
    expect(errorCall).toBeDefined();
  });

  test("works without eventService (optional dependency)", async () => {
    const fetcher = makeMockFetcher([makeIssuePage(2)]);
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();

    // No eventService passed — should not throw
    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    const result = await service.pullSync();

    expect(result.totalIssues).toBe(2);
  });
});

// ---------------------------------------------------------------------------
// PullSyncService rate limit abort
// ---------------------------------------------------------------------------

describe("PullSyncService rate limit handling", () => {
  test("aborts when fetcher throws rate limit error", async () => {
    const fetcher = {
      fetchRateLimit: mock(async (): Promise<GitHubRateLimitResponse> => ({
        remaining: 4500,
        resetAt: "2026-01-01T01:00:00Z",
      })),
      fetchAllPages: mock(async function* () {
        yield makeIssuePage(2, 1, true, "c1");
        throw new Error("Rate limit: remaining points (400) below threshold (500). Resets at 2026-01-01T01:00:00Z");
      }),
      fetchCommentPage: mock(async () => ({
        pageInfo: { hasNextPage: false, endCursor: null },
        nodes: [],
      })),
    };
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();
    const eventService = makeMockEventService();

    const service = new PullSyncService(
      fetcher as never,
      mapper as never,
      upserter as never,
      eventService as never
    );

    await expect(service.pullSync()).rejects.toThrow(/rate limit/i);
  });
});

// ---------------------------------------------------------------------------
// PullSyncService comment overflow handling
// ---------------------------------------------------------------------------

describe("PullSyncService comment overflow", () => {
  test("fetches extra comment pages for issues with comments.pageInfo.hasNextPage=true", async () => {
    // An issue node with comment overflow
    const issueWithOverflow = {
      number: 1,
      title: "Heavy issue",
      body: "lots of comments",
      state: "OPEN" as const,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      url: "https://github.com/owner/repo/issues/1",
      parent: null,
      labels: { nodes: [] },
      projectItems: { nodes: [] },
      comments: {
        totalCount: 75,
        pageInfo: { hasNextPage: true, endCursor: "cursor_at_50" },
        nodes: Array.from({ length: 50 }, (_, i) => ({
          body: `Comment ${i + 1}`,
          author: { login: "user" },
          createdAt: `2026-01-0${i < 9 ? "1" : "2"}T00:00:${String(i).padStart(2, "0")}Z`,
          updatedAt: `2026-01-0${i < 9 ? "1" : "2"}T00:00:${String(i).padStart(2, "0")}Z`,
        })),
      },
    };

    const issuePage: GitHubIssuePage = {
      totalCount: 1,
      pageInfo: { hasNextPage: false, endCursor: null },
      rateLimitRemaining: 4500,
      nodes: [issueWithOverflow],
    };

    const fetchCommentPageMock = mock(async () => ({
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [
        { body: "Comment 51", author: { login: "user" }, createdAt: "2026-01-02T00:01:00Z", updatedAt: "2026-01-02T00:01:00Z" },
      ],
    }));

    const fetcher = {
      fetchRateLimit: mock(async (): Promise<GitHubRateLimitResponse> => ({
        remaining: 4500,
        resetAt: "2026-01-01T01:00:00Z",
      })),
      fetchAllPages: mock(async function* () {
        yield issuePage;
      }),
      fetchCommentPage: fetchCommentPageMock,
    };

    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();

    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    await service.pullSync();

    // fetchCommentPage should have been called for the overflow issue
    expect(fetchCommentPageMock.mock.calls.length).toBeGreaterThanOrEqual(1);
    const [issueNumber, cursor] = fetchCommentPageMock.mock.calls[0] as [number, string];
    expect(issueNumber).toBe(1);
    expect(cursor).toBe("cursor_at_50");
  });
});

// ---------------------------------------------------------------------------
// PullSyncService pointsConsumed tracking
// ---------------------------------------------------------------------------

describe("PullSyncService pointsConsumed", () => {
  test("tracks points consumed from page responses", async () => {
    const page1 = makeIssuePage(2, 1, true, "c1", 4500);
    const page2 = makeIssuePage(2, 3, false, null, 4450);
    const fetcher = makeMockFetcher([page1, page2]);
    const mapper = makeMockMapper();
    const upserter = makeMockUpserter();

    const service = new PullSyncService(fetcher as never, mapper as never, upserter as never);
    const result = await service.pullSync();

    // Points consumed = initial (4500) - final (4450) = 50
    expect(result.pointsConsumed).toBe(50);
  });
});
