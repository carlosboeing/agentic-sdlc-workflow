import { describe, test, expect, beforeEach, spyOn } from "bun:test";
import {
  GitHubPullFetcher,
  type GitHubPullFetcherConfig,
  type GitHubIssuePage,
  type GitHubRateLimitResponse,
} from "../../src/adapters/github-pull";

// ---------------------------------------------------------------------------
// Fixtures: minimal GitHub GraphQL response shapes
// ---------------------------------------------------------------------------

function makeIssueNode(overrides: Partial<{
  number: number;
  title: string;
  body: string | null;
  state: "OPEN" | "CLOSED";
  createdAt: string;
  updatedAt: string;
  url: string;
  parent: { number: number } | null;
  labels: { nodes: Array<{ name: string }> };
  projectItems: {
    nodes: Array<{
      fieldValues: {
        nodes: Array<{
          __typename?: string;
          name?: string;
          field?: { name: string };
        }>;
      };
    }>;
  };
  comments: {
    totalCount: number;
    pageInfo: { hasNextPage: boolean; endCursor: string | null };
    nodes: Array<{
      body: string;
      author: { login: string } | null;
      createdAt: string;
      updatedAt: string;
    }>;
  };
}> = {}) {
  return {
    number: overrides.number ?? 1,
    title: overrides.title ?? "Test Issue",
    body: overrides.body ?? "Test body",
    state: overrides.state ?? "OPEN",
    createdAt: overrides.createdAt ?? "2026-01-01T00:00:00Z",
    updatedAt: overrides.updatedAt ?? "2026-01-01T00:00:00Z",
    url: overrides.url ?? "https://github.com/owner/repo/issues/1",
    parent: overrides.parent ?? null,
    labels: overrides.labels ?? { nodes: [] },
    projectItems: overrides.projectItems ?? { nodes: [] },
    comments: overrides.comments ?? {
      totalCount: 0,
      pageInfo: { hasNextPage: false, endCursor: null },
      nodes: [],
    },
  };
}

function makePageResponse(
  issues: ReturnType<typeof makeIssueNode>[],
  hasNextPage: boolean,
  endCursor: string | null,
  totalCount = issues.length,
  rateLimitRemaining = 4500
): { stdout: string; stderr: string; exitCode: number } {
  return {
    stdout: JSON.stringify({
      data: {
        repository: {
          issues: {
            totalCount,
            pageInfo: { hasNextPage, endCursor },
            nodes: issues,
          },
        },
        rateLimit: {
          remaining: rateLimitRemaining,
          resetAt: "2026-01-01T01:00:00Z",
        },
      },
    }),
    stderr: "",
    exitCode: 0,
  };
}

function makeRateLimitResponse(remaining: number, resetAt = "2026-01-01T01:00:00Z") {
  return {
    stdout: JSON.stringify({
      data: {
        rateLimit: { remaining, resetAt },
      },
    }),
    stderr: "",
    exitCode: 0,
  };
}

function makeCommentPageResponse(
  comments: Array<{
    body: string;
    author: { login: string } | null;
    createdAt: string;
    updatedAt: string;
  }>,
  hasNextPage: boolean,
  endCursor: string | null
) {
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
// Config fixture
// ---------------------------------------------------------------------------

const DEFAULT_CONFIG: GitHubPullFetcherConfig = {
  repo: "owner/test-repo",
  pageSize: 50,
  maxPoints: 1000,
};

// ---------------------------------------------------------------------------
// fetchRateLimit
// ---------------------------------------------------------------------------

describe("GitHubPullFetcher.fetchRateLimit", () => {
  let fetcher: GitHubPullFetcher;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    fetcher = new GitHubPullFetcher(DEFAULT_CONFIG);
    runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");
  });

  test("queries rateLimit before sync starts", async () => {
    runGhSpy.mockResolvedValue(makeRateLimitResponse(4500));

    const result = await fetcher.fetchRateLimit();

    expect(result.remaining).toBe(4500);
    expect(result.resetAt).toBe("2026-01-01T01:00:00Z");
    expect(runGhSpy).toHaveBeenCalledTimes(1);
    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args).toContain("api");
    expect(args).toContain("graphql");
    // Query must include rateLimit
    const queryArg = args.find(a => a.includes("rateLimit"));
    expect(queryArg).toBeDefined();
  });

  test("throws on gh CLI error", async () => {
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "not authenticated", exitCode: 1 });
    await expect(fetcher.fetchRateLimit()).rejects.toThrow(/rate limit check failed/i);
  });
});

// ---------------------------------------------------------------------------
// fetchPage
// ---------------------------------------------------------------------------

describe("GitHubPullFetcher.fetchPage", () => {
  let fetcher: GitHubPullFetcher;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    fetcher = new GitHubPullFetcher(DEFAULT_CONFIG);
    runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");
  });

  test("fetches first page without cursor", async () => {
    const issues = [makeIssueNode({ number: 1 }), makeIssueNode({ number: 2 })];
    runGhSpy.mockResolvedValue(makePageResponse(issues, false, null));

    const page = await fetcher.fetchPage(null);

    expect(page.nodes).toHaveLength(2);
    expect(page.pageInfo.hasNextPage).toBe(false);
    expect(page.pageInfo.endCursor).toBeNull();
    expect(page.totalCount).toBe(2);
    expect(runGhSpy).toHaveBeenCalledTimes(1);
  });

  test("fetches subsequent page with cursor", async () => {
    const issues = [makeIssueNode({ number: 51 })];
    runGhSpy.mockResolvedValue(makePageResponse(issues, false, null, 51));

    await fetcher.fetchPage("cursor_abc123");

    const [args] = runGhSpy.mock.calls[0] as [string[]];
    // Cursor should appear in the query arguments
    expect(args.join(" ")).toContain("cursor_abc123");
  });

  test("page response includes rateLimit remaining", async () => {
    const issues = [makeIssueNode()];
    runGhSpy.mockResolvedValue(makePageResponse(issues, false, null, 1, 4200));

    const page = await fetcher.fetchPage(null);

    expect(page.rateLimitRemaining).toBe(4200);
  });

  test("uses pageSize from config", async () => {
    const smallFetcher = new GitHubPullFetcher({ repo: "owner/repo", pageSize: 10 });
    const runGhSmallSpy = spyOn(smallFetcher as unknown as Record<string, unknown>, "_runGh");
    runGhSmallSpy.mockResolvedValue(makePageResponse([makeIssueNode()], false, null));

    await smallFetcher.fetchPage(null);

    const [args] = runGhSmallSpy.mock.calls[0] as [string[]];
    expect(args.join(" ")).toContain("10");
  });

  test("throws descriptive error when gh CLI fails", async () => {
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "network error", exitCode: 1 });
    await expect(fetcher.fetchPage(null)).rejects.toThrow(/fetchPage.*failed/i);
  });

  test("throws descriptive error on malformed JSON", async () => {
    runGhSpy.mockResolvedValue({ stdout: "not-json", stderr: "", exitCode: 0 });
    await expect(fetcher.fetchPage(null)).rejects.toThrow(/parse/i);
  });
});

// ---------------------------------------------------------------------------
// fetchAllPages (cursor pagination loop)
// ---------------------------------------------------------------------------

describe("GitHubPullFetcher.fetchAllPages", () => {
  let fetcher: GitHubPullFetcher;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    fetcher = new GitHubPullFetcher(DEFAULT_CONFIG);
    runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");
  });

  test("single-page repo: loops once and returns all issues", async () => {
    const issues = [makeIssueNode({ number: 1 }), makeIssueNode({ number: 2 })];
    runGhSpy.mockResolvedValue(makePageResponse(issues, false, null, 2));

    const pages: GitHubIssuePage[] = [];
    for await (const page of fetcher.fetchAllPages()) {
      pages.push(page);
    }

    expect(pages).toHaveLength(1);
    expect(pages[0].nodes).toHaveLength(2);
    expect(runGhSpy).toHaveBeenCalledTimes(1);
  });

  test("multi-page repo: loops until hasNextPage is false", async () => {
    // Page 1: hasNextPage true
    runGhSpy.mockResolvedValueOnce(
      makePageResponse(
        [makeIssueNode({ number: 1 }), makeIssueNode({ number: 2 })],
        true,
        "cursor_page1",
        4
      )
    );
    // Page 2: hasNextPage true
    runGhSpy.mockResolvedValueOnce(
      makePageResponse(
        [makeIssueNode({ number: 3 }), makeIssueNode({ number: 4 })],
        true,
        "cursor_page2",
        4
      )
    );
    // Page 3: hasNextPage false
    runGhSpy.mockResolvedValueOnce(
      makePageResponse(
        [makeIssueNode({ number: 5 })],
        false,
        null,
        5
      )
    );

    const pages: GitHubIssuePage[] = [];
    for await (const page of fetcher.fetchAllPages()) {
      pages.push(page);
    }

    expect(pages).toHaveLength(3);
    expect(pages[0].nodes[0].number).toBe(1);
    expect(pages[1].nodes[0].number).toBe(3);
    expect(pages[2].nodes[0].number).toBe(5);
    expect(runGhSpy).toHaveBeenCalledTimes(3);
  });

  test("passes cursor from page N to page N+1", async () => {
    runGhSpy.mockResolvedValueOnce(
      makePageResponse([makeIssueNode({ number: 1 })], true, "cursor_abc", 2)
    );
    runGhSpy.mockResolvedValueOnce(
      makePageResponse([makeIssueNode({ number: 2 })], false, null, 2)
    );

    const pages: GitHubIssuePage[] = [];
    for await (const page of fetcher.fetchAllPages()) {
      pages.push(page);
    }

    expect(pages).toHaveLength(2);
    // Second call should include the cursor from the first page
    const [secondCallArgs] = runGhSpy.mock.calls[1] as [string[]];
    expect(secondCallArgs.join(" ")).toContain("cursor_abc");
  });

  test("aborts when rate limit drops below 500", async () => {
    // First page: rate limit is fine
    runGhSpy.mockResolvedValueOnce(
      makePageResponse([makeIssueNode({ number: 1 })], true, "cursor_next", 2, 800)
    );
    // Second page would drop below 500 — but we need the fetcher to detect the low remaining
    // from the first page response (remaining=800 is > 500, so it should continue)
    // Let's use a value of 400 to trigger the abort
    runGhSpy.mockResolvedValueOnce(
      makePageResponse([makeIssueNode({ number: 2 })], true, "cursor_next2", 3, 400)
    );

    const pages: GitHubIssuePage[] = [];
    let thrownError: unknown;
    try {
      for await (const page of fetcher.fetchAllPages()) {
        pages.push(page);
      }
    } catch (err) {
      thrownError = err;
    }

    // Should have fetched first two pages, then aborted
    expect(thrownError).toBeDefined();
    expect((thrownError as Error).message).toMatch(/rate limit|points/i);
  });
});

// ---------------------------------------------------------------------------
// Retry logic
// ---------------------------------------------------------------------------

describe("GitHubPullFetcher retry logic", () => {
  let fetcher: GitHubPullFetcher;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    fetcher = new GitHubPullFetcher(DEFAULT_CONFIG);
    runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");
  });

  test("retries failed page up to 3 times before throwing", async () => {
    // All calls fail
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "timeout", exitCode: 1 });

    await expect(fetcher.fetchPage(null)).rejects.toThrow();

    // Should have retried: 1 original + up to 3 retries = up to 4 calls max
    expect(runGhSpy.mock.calls.length).toBeGreaterThanOrEqual(2);
    expect(runGhSpy.mock.calls.length).toBeLessThanOrEqual(4);
  });

  test("succeeds on second attempt after one failure", async () => {
    const issues = [makeIssueNode({ number: 1 })];
    runGhSpy.mockResolvedValueOnce({ stdout: "", stderr: "timeout", exitCode: 1 });
    runGhSpy.mockResolvedValueOnce(makePageResponse(issues, false, null));

    const page = await fetcher.fetchPage(null);

    expect(page.nodes).toHaveLength(1);
    expect(runGhSpy).toHaveBeenCalledTimes(2);
  });

  test("succeeds on third attempt after two failures", async () => {
    const issues = [makeIssueNode()];
    runGhSpy.mockResolvedValueOnce({ stdout: "", stderr: "err1", exitCode: 1 });
    runGhSpy.mockResolvedValueOnce({ stdout: "", stderr: "err2", exitCode: 1 });
    runGhSpy.mockResolvedValueOnce(makePageResponse(issues, false, null));

    const page = await fetcher.fetchPage(null);

    expect(page.nodes).toHaveLength(1);
    expect(runGhSpy).toHaveBeenCalledTimes(3);
  });
});

// ---------------------------------------------------------------------------
// Comment overflow pagination
// ---------------------------------------------------------------------------

describe("GitHubPullFetcher.fetchCommentPage", () => {
  let fetcher: GitHubPullFetcher;
  let runGhSpy: ReturnType<typeof spyOn>;

  beforeEach(() => {
    fetcher = new GitHubPullFetcher(DEFAULT_CONFIG);
    runGhSpy = spyOn(fetcher as unknown as Record<string, unknown>, "_runGh");
  });

  test("fetches additional comments for overflow issue", async () => {
    const comments = [
      { body: "Comment 51", author: { login: "user1" }, createdAt: "2026-01-01T00:00:51Z", updatedAt: "2026-01-01T00:00:51Z" },
      { body: "Comment 52", author: { login: "user2" }, createdAt: "2026-01-01T00:00:52Z", updatedAt: "2026-01-01T00:00:52Z" },
    ];
    runGhSpy.mockResolvedValue(makeCommentPageResponse(comments, false, null));

    const result = await fetcher.fetchCommentPage(42, "cursor_after_50");

    expect(result.nodes).toHaveLength(2);
    expect(result.nodes[0].body).toBe("Comment 51");
    expect(result.pageInfo.hasNextPage).toBe(false);
    const [args] = runGhSpy.mock.calls[0] as [string[]];
    expect(args.join(" ")).toContain("42");
    expect(args.join(" ")).toContain("cursor_after_50");
  });

  test("detects multi-page comment overflow", async () => {
    const page1Comments = [{ body: "Comment 51", author: { login: "u1" }, createdAt: "2026-01-01T00:01:00Z", updatedAt: "2026-01-01T00:01:00Z" }];
    const page2Comments = [{ body: "Comment 52", author: { login: "u2" }, createdAt: "2026-01-01T00:02:00Z", updatedAt: "2026-01-01T00:02:00Z" }];

    runGhSpy.mockResolvedValueOnce(makeCommentPageResponse(page1Comments, true, "cursor_mid"));
    runGhSpy.mockResolvedValueOnce(makeCommentPageResponse(page2Comments, false, null));

    const page1 = await fetcher.fetchCommentPage(10, "cursor_start");
    expect(page1.pageInfo.hasNextPage).toBe(true);
    expect(page1.pageInfo.endCursor).toBe("cursor_mid");

    const page2 = await fetcher.fetchCommentPage(10, "cursor_mid");
    expect(page2.pageInfo.hasNextPage).toBe(false);
    expect(page2.nodes[0].body).toBe("Comment 52");
  });

  test("throws on failure", async () => {
    runGhSpy.mockResolvedValue({ stdout: "", stderr: "error", exitCode: 1 });
    await expect(fetcher.fetchCommentPage(1, "cursor")).rejects.toThrow(/fetchCommentPage.*failed/i);
  });
});

// ---------------------------------------------------------------------------
// Configuration defaults
// ---------------------------------------------------------------------------

describe("GitHubPullFetcher configuration", () => {
  test("defaults pageSize to 50", () => {
    const f = new GitHubPullFetcher({ repo: "owner/repo" });
    expect((f as unknown as Record<string, unknown>).pageSize).toBe(50);
  });

  test("defaults maxPoints to 1000", () => {
    const f = new GitHubPullFetcher({ repo: "owner/repo" });
    expect((f as unknown as Record<string, unknown>).maxPoints).toBe(1000);
  });

  test("accepts custom pageSize", () => {
    const f = new GitHubPullFetcher({ repo: "owner/repo", pageSize: 25 });
    expect((f as unknown as Record<string, unknown>).pageSize).toBe(25);
  });

  test("accepts custom maxPoints", () => {
    const f = new GitHubPullFetcher({ repo: "owner/repo", maxPoints: 2000 });
    expect((f as unknown as Record<string, unknown>).maxPoints).toBe(2000);
  });
});
