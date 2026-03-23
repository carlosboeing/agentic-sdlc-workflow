/**
 * GitHubPullFetcher — fetches all issues from GitHub via GraphQL pagination.
 *
 * Uses the same `_runGh()` subprocess pattern as `GitHubAdapter` so tests
 * can spy on a single point without patching global process spawning.
 *
 * Architecture:
 *   fetchRateLimit()    — pre-flight rate limit check
 *   fetchAllPages()     — async generator, yields one page at a time
 *   fetchPage()         — single page fetch with retry logic
 *   fetchCommentPage()  — follow-up pagination for issues with >50 comments
 */

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

export interface GitHubPullFetcherConfig {
  /** GitHub repository in "owner/repo" format. */
  repo: string;
  /** Issues per page. Default: 50. Max: 100. */
  pageSize?: number;
  /** Abort when remaining GraphQL points drop below this. Default: 500. */
  maxPoints?: number;
}

// ---------------------------------------------------------------------------
// Response shapes (GraphQL output)
// ---------------------------------------------------------------------------

export interface GitHubIssueCommentNode {
  body: string;
  author: { login: string } | null;
  createdAt: string;
  updatedAt: string;
}

export interface GitHubIssueNode {
  number: number;
  title: string;
  body: string | null;
  state: "OPEN" | "CLOSED";
  createdAt: string;
  updatedAt: string;
  url: string;
  parent: { number: number } | null;
  labels: {
    nodes: Array<{ name: string }>;
  };
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
    nodes: GitHubIssueCommentNode[];
  };
}

export interface GitHubIssuePage {
  totalCount: number;
  pageInfo: { hasNextPage: boolean; endCursor: string | null };
  /** Remaining GraphQL points from the page response rateLimit field. */
  rateLimitRemaining: number;
  /** ISO timestamp when the rate limit resets, from the page response rateLimit field. */
  rateLimitResetAt: string;
  nodes: GitHubIssueNode[];
}

export interface GitHubCommentPage {
  pageInfo: { hasNextPage: boolean; endCursor: string | null };
  nodes: GitHubIssueCommentNode[];
}

export interface GitHubRateLimitResponse {
  remaining: number;
  resetAt: string;
}

// ---------------------------------------------------------------------------
// Subprocess result (same as GitHubAdapter)
// ---------------------------------------------------------------------------

interface GhResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

// ---------------------------------------------------------------------------
// GitHubPullFetcher
// ---------------------------------------------------------------------------

/**
 * Fetches GitHub issues via paginated GraphQL queries using the `gh` CLI.
 *
 * Reuses the `_runGh()` pattern from `GitHubAdapter` for consistent
 * subprocess handling and testability.
 */
export class GitHubPullFetcher {
  readonly pageSize: number;
  readonly maxPoints: number;
  private readonly repo: string;
  private readonly maxRetries = 3;
  /** Minimum retry delay in ms — overridable for tests via constructor extension. */
  protected retryDelayMs = 500;

  constructor(config: GitHubPullFetcherConfig) {
    this.repo = config.repo;
    this.pageSize = config.pageSize ?? 50;
    this.maxPoints = config.maxPoints ?? 1000;
  }

  // -------------------------------------------------------------------------
  // fetchRateLimit
  // -------------------------------------------------------------------------

  /**
   * Query the current GraphQL rate limit status.
   * Called before the sync starts to verify budget availability.
   */
  async fetchRateLimit(): Promise<GitHubRateLimitResponse> {
    const args = [
      "api",
      "graphql",
      "-f",
      `query=query { rateLimit { remaining resetAt } }`,
    ];

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `Rate limit check failed (exit ${result.exitCode}): ${result.stderr.trim()}`
      );
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(result.stdout);
    } catch {
      throw new Error(`Rate limit check failed: could not parse response: ${result.stdout}`);
    }

    const rateLimit = (parsed as { data?: { rateLimit?: GitHubRateLimitResponse } })
      ?.data?.rateLimit;

    if (!rateLimit) {
      throw new Error(`Rate limit check failed: missing rateLimit field in response`);
    }

    return rateLimit;
  }

  // -------------------------------------------------------------------------
  // fetchPage (with retry)
  // -------------------------------------------------------------------------

  /**
   * Fetch a single page of issues. Retries up to `maxRetries` times on failure
   * with exponential backoff.
   *
   * @param cursor - GraphQL cursor for pagination, or null for first page.
   */
  async fetchPage(cursor: string | null): Promise<GitHubIssuePage> {
    const [repoOwner, repoName] = this.repo.split("/");

    const query = `
query($owner: String!, $name: String!, $first: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    issues(first: $first, after: $cursor, orderBy: {field: CREATED_AT, direction: ASC}) {
      totalCount
      pageInfo {
        hasNextPage
        endCursor
      }
      nodes {
        number
        title
        body
        state
        createdAt
        updatedAt
        url
        parent {
          number
        }
        labels(first: 20) {
          nodes { name }
        }
        projectItems(first: 1) {
          nodes {
            fieldValues(first: 10) {
              nodes {
                ... on ProjectV2ItemFieldSingleSelectValue {
                  name
                  field { ... on ProjectV2SingleSelectField { name } }
                }
              }
            }
          }
        }
        comments(first: 50) {
          totalCount
          pageInfo { hasNextPage endCursor }
          nodes {
            body
            author { login }
            createdAt
            updatedAt
          }
        }
      }
    }
  }
  rateLimit {
    remaining
    resetAt
  }
}`.trim();

    const buildArgs = (): string[] => {
      const args = [
        "api",
        "graphql",
        "-f",
        `query=${query}`,
        "-f",
        `owner=${repoOwner}`,
        "-f",
        `name=${repoName}`,
        "-F",
        `first=${this.pageSize}`,
      ];

      if (cursor !== null) {
        args.push("-f", `cursor=${cursor}`);
      }

      return args;
    };

    let lastError: Error | null = null;
    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      if (attempt > 0) {
        // Exponential backoff: 500ms, 1000ms, 2000ms
        const delay = this.retryDelayMs * Math.pow(2, attempt - 1);
        await this._sleep(delay);
      }

      const result = await this._runGh(buildArgs());

      if (result.exitCode !== 0) {
        lastError = new Error(
          `fetchPage failed (exit ${result.exitCode}): ${result.stderr.trim()}`
        );
        continue;
      }

      let parsed: unknown;
      try {
        parsed = JSON.parse(result.stdout);
      } catch (err) {
        throw new Error(`fetchPage failed: could not parse response: ${result.stdout.slice(0, 200)}`);
      }

      const issuesConn = (
        parsed as {
          data?: {
            repository?: {
              issues?: {
                totalCount: number;
                pageInfo: { hasNextPage: boolean; endCursor: string | null };
                nodes: GitHubIssueNode[];
              };
            };
            rateLimit?: { remaining: number; resetAt: string };
          };
        }
      )?.data;

      if (!issuesConn?.repository?.issues) {
        lastError = new Error(`fetchPage failed: unexpected response shape: ${result.stdout.slice(0, 200)}`);
        continue;
      }

      const { totalCount, pageInfo, nodes } = issuesConn.repository.issues;
      const rateLimitRemaining = issuesConn.rateLimit?.remaining ?? 5000;
      const rateLimitResetAt = issuesConn.rateLimit?.resetAt ?? "";

      return { totalCount, pageInfo, nodes, rateLimitRemaining, rateLimitResetAt };
    }

    throw lastError ?? new Error("fetchPage failed: unknown error after retries");
  }

  // -------------------------------------------------------------------------
  // fetchAllPages (async generator)
  // -------------------------------------------------------------------------

  /**
   * Async generator that yields one `GitHubIssuePage` per GraphQL call.
   * Loops until `pageInfo.hasNextPage` is false.
   *
   * Throws if remaining rate limit points drop below the safety threshold (500).
   */
  async *fetchAllPages(): AsyncGenerator<GitHubIssuePage> {
    let cursor: string | null = null;
    const rateLimitThreshold = 500;

    do {
      const page = await this.fetchPage(cursor);
      yield page;

      if (page.rateLimitRemaining < rateLimitThreshold) {
        throw new Error(
          `Rate limit: remaining points (${page.rateLimitRemaining}) below threshold (${rateLimitThreshold}). Resets at ${page.rateLimitResetAt || "unknown"}.`
        );
      }

      cursor = page.pageInfo.hasNextPage ? page.pageInfo.endCursor : null;
    } while (cursor !== null);
  }

  // -------------------------------------------------------------------------
  // fetchCommentPage
  // -------------------------------------------------------------------------

  /**
   * Fetch a page of comments for a specific issue (for overflow pagination).
   *
   * @param issueNumber - GitHub issue number.
   * @param cursor - Cursor for the next page of comments.
   */
  async fetchCommentPage(issueNumber: number, cursor: string): Promise<GitHubCommentPage> {
    const [repoOwner, repoName] = this.repo.split("/");

    const query = `
query($owner: String!, $name: String!, $number: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    issue(number: $number) {
      comments(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          body
          author { login }
          createdAt
          updatedAt
        }
      }
    }
  }
}`.trim();

    const args = [
      "api",
      "graphql",
      "-f",
      `query=${query}`,
      "-f",
      `owner=${repoOwner}`,
      "-f",
      `name=${repoName}`,
      "-F",
      `number=${issueNumber}`,
      "-f",
      `cursor=${cursor}`,
    ];

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `fetchCommentPage failed for issue #${issueNumber} (exit ${result.exitCode}): ${result.stderr.trim()}`
      );
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(result.stdout);
    } catch {
      throw new Error(
        `fetchCommentPage failed: could not parse response for issue #${issueNumber}`
      );
    }

    const commentConn = (
      parsed as {
        data?: {
          repository?: {
            issue?: {
              comments?: {
                pageInfo: { hasNextPage: boolean; endCursor: string | null };
                nodes: GitHubIssueCommentNode[];
              };
            };
          };
        };
      }
    )?.data?.repository?.issue?.comments;

    if (!commentConn) {
      throw new Error(
        `fetchCommentPage failed: unexpected response shape for issue #${issueNumber}`
      );
    }

    return { pageInfo: commentConn.pageInfo, nodes: commentConn.nodes };
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Execute a `gh` CLI command and return stdout, stderr, and exit code.
   * Extracted to a method so tests can spy on it without patching globals.
   */
  async _runGh(args: string[]): Promise<GhResult> {
    const proc = Bun.spawn(["gh", ...args], {
      stdout: "pipe",
      stderr: "pipe",
    });

    const [stdoutBuf, stderrBuf] = await Promise.all([
      new Response(proc.stdout).text(),
      new Response(proc.stderr).text(),
    ]);

    const exitCode = await proc.exited;

    return { stdout: stdoutBuf, stderr: stderrBuf, exitCode };
  }

  /** Sleep helper extracted for testability (tests override retryDelayMs=0). */
  protected async _sleep(ms: number): Promise<void> {
    await Bun.sleep(ms);
  }
}
