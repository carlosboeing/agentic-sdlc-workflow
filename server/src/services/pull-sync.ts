/**
 * PullSyncService — orchestrates the GitHub-to-SQLite pull sync.
 *
 * Responsibilities:
 *   1. Iterate over pages from GitHubPullFetcher
 *   2. Map each issue via IssueMapper
 *   3. Upsert each page via DatabaseUpserter
 *   4. Trigger hierarchy linking after all pages complete
 *   5. Emit progress events via optional EventService
 *   6. Return a PullSyncResult summary
 *
 * The IssueMapper and DatabaseUpserter dependencies are injected via
 * constructor so tests can mock them independently (E01-S02 provides
 * the real implementations).
 */

import type { GitHubPullFetcher, GitHubIssuePage, GitHubIssueNode } from "../adapters/github-pull";
import type { EventService } from "../api/websocket";

// ---------------------------------------------------------------------------
// Public interfaces
// ---------------------------------------------------------------------------

export interface PullSyncOptions {
  /** Only sync issues matching these labels. Default: all issues. */
  filterLabels?: string[];
  /** Only sync issues updated after this ISO timestamp. Default: all. */
  updatedSince?: string;
  /** Maximum GraphQL points to consume before aborting. Default: 1000. */
  maxPoints?: number;
  /** Include comments in the sync. Default: true. */
  includeComments?: boolean;
}

export interface PullSyncResult {
  totalIssues: number;
  itemsCreated: number;
  itemsUpdated: number;
  labelsCreated: number;
  commentsCreated: number;
  commentsUpdated: number;
  hierarchyLinked: number;
  pointsConsumed: number;
  durationMs: number;
  errors: string[];
}

// ---------------------------------------------------------------------------
// Dependency interfaces (implemented in E01-S02)
// ---------------------------------------------------------------------------

/** Maps a raw GitHub issue node to SQLite-ready types. */
export interface IssueMapper {
  mapIssue(issue: GitHubIssueNode): MappedIssue;
}

/** Result of mapping a single GitHub issue. */
export interface MappedIssue {
  item: {
    id: number;
    title: string;
    body: string | null;
    type: import("../types").ItemType;
    status: import("../types").BoardStatus;
    state: import("../types").ItemState;
    externalId: string;
    externalUrl: string;
    createdAt: string;
    updatedAt: string;
  };
  labels: string[];
  parentNumber: number | null;
  comments: Array<{
    body: string;
    author: string;
    createdAt: string;
    updatedAt: string;
  }>;
}

/** Result of upserting a page of issues. */
export interface UpsertPageResult {
  created: number;
  updated: number;
  labelsCreated: number;
  commentsCreated: number;
  commentsUpdated: number;
}

/** Result of upserting comments only (no item data). */
export interface UpsertCommentsResult {
  commentsCreated: number;
  commentsUpdated: number;
}

/** Upserts mapped issues into SQLite. */
export interface DatabaseUpserter {
  upsertPage(issues: MappedIssue[]): UpsertPageResult;
  /**
   * Upsert additional comments for a specific item without touching any item fields.
   * Used for comment overflow pagination — avoids overwriting real item data with dummy values.
   *
   * @param itemId - The item ID (GitHub issue number) to attach comments to.
   * @param comments - Additional comment nodes to upsert.
   */
  upsertComments(
    itemId: number,
    comments: MappedIssue["comments"]
  ): UpsertCommentsResult;
  linkHierarchy(parentMap: Map<number, number>): number;
}

// ---------------------------------------------------------------------------
// PullSyncService
// ---------------------------------------------------------------------------

/**
 * Orchestrates the full pull sync lifecycle.
 *
 * Constructor dependencies:
 *   - fetcher: GitHubPullFetcher — provides paginated GitHub data
 *   - mapper:  IssueMapper       — converts raw nodes to SQLite types
 *   - upserter: DatabaseUpserter — writes mapped data to SQLite
 *   - eventService?: EventService — optional, emits progress events
 */
export class PullSyncService {
  constructor(
    private readonly fetcher: GitHubPullFetcher,
    private readonly mapper: IssueMapper,
    private readonly upserter: DatabaseUpserter,
    private readonly eventService?: Pick<EventService, "broadcast">
  ) {}

  /**
   * Run a full pull sync from GitHub to SQLite.
   *
   * Steps:
   *   1. Iterate pages from fetcher
   *   2. Map each issue to SQLite types
   *   3. Upsert each page (accumulate counters)
   *   4. Track comment overflow issues
   *   5. Fetch additional comment pages for overflow issues
   *   6. Link parent-child hierarchy
   *   7. Return PullSyncResult
   *
   * Throws on fatal errors (rate limit, network failure after retries).
   * Emits sync:pull:error before re-throwing.
   */
  async pullSync(_options?: PullSyncOptions): Promise<PullSyncResult> {
    const startMs = Date.now();

    // Pre-flight: verify rate limit budget before starting the sync.
    const rateLimitThreshold = 500;
    const preflightRateLimit = await this.fetcher.fetchRateLimit();
    if (preflightRateLimit.remaining < rateLimitThreshold) {
      throw new Error(
        `Rate limit: remaining points (${preflightRateLimit.remaining}) below threshold (${rateLimitThreshold}). Resets at ${preflightRateLimit.resetAt}.`
      );
    }

    const result: PullSyncResult = {
      totalIssues: 0,
      itemsCreated: 0,
      itemsUpdated: 0,
      labelsCreated: 0,
      commentsCreated: 0,
      commentsUpdated: 0,
      hierarchyLinked: 0,
      pointsConsumed: 0,
      durationMs: 0,
      errors: [],
    };

    /** Map from child issue number -> parent issue number for hierarchy linking. */
    const parentMap = new Map<number, number>();
    /** Issues whose comment list was truncated (hasNextPage=true). */
    const overflowIssues: Array<{ number: number; cursor: string }> = [];

    let initialRateLimitRemaining: number | null = null;
    let finalRateLimitRemaining: number | null = null;
    let firstPage = true;
    let pageIndex = 0;

    try {
      for await (const page of this.fetcher.fetchAllPages()) {
        if (firstPage) {
          result.totalIssues = page.totalCount;
          initialRateLimitRemaining = page.rateLimitRemaining;

          this._emit("sync:pull:started", { totalCount: page.totalCount });
          firstPage = false;
        }

        finalRateLimitRemaining = page.rateLimitRemaining;

        // Map all issues on this page
        const mappedIssues: MappedIssue[] = [];
        for (const node of page.nodes) {
          const mapped = this.mapper.mapIssue(node);
          mappedIssues.push(mapped);

          // Accumulate parent map for hierarchy linking pass
          if (mapped.parentNumber !== null) {
            parentMap.set(mapped.item.id, mapped.parentNumber);
          }

          // Track issues with truncated comment lists
          if (node.comments.pageInfo.hasNextPage && node.comments.pageInfo.endCursor) {
            overflowIssues.push({
              number: node.number,
              cursor: node.comments.pageInfo.endCursor,
            });
          }
        }

        // Upsert this page
        const upsertResult = this.upserter.upsertPage(mappedIssues);
        result.itemsCreated += upsertResult.created;
        result.itemsUpdated += upsertResult.updated;
        result.labelsCreated += upsertResult.labelsCreated;
        result.commentsCreated += upsertResult.commentsCreated;
        result.commentsUpdated += upsertResult.commentsUpdated;

        pageIndex++;
        this._emit("sync:pull:progress", {
          page: pageIndex,
          itemsProcessed: result.itemsCreated + result.itemsUpdated,
        });
      }

      // Fetch additional comment pages for overflow issues.
      // Use upsertComments (not upsertPage) to avoid overwriting real item data with dummy values.
      for (const overflow of overflowIssues) {
        let cursor: string | null = overflow.cursor;
        while (cursor !== null) {
          const commentPage = await this.fetcher.fetchCommentPage(overflow.number, cursor);

          const additionalComments = commentPage.nodes.map(n => ({
            body: n.body,
            author: n.author?.login ?? "unknown",
            createdAt: n.createdAt,
            updatedAt: n.updatedAt,
          }));

          const overflowResult = this.upserter.upsertComments(overflow.number, additionalComments);
          result.commentsCreated += overflowResult.commentsCreated;
          result.commentsUpdated += overflowResult.commentsUpdated;

          cursor = commentPage.pageInfo.hasNextPage ? commentPage.pageInfo.endCursor : null;
        }
      }

      // Link parent-child hierarchy in a final pass
      result.hierarchyLinked = this.upserter.linkHierarchy(parentMap);

      // Compute points consumed
      if (initialRateLimitRemaining !== null && finalRateLimitRemaining !== null) {
        result.pointsConsumed = initialRateLimitRemaining - finalRateLimitRemaining;
      }

      result.durationMs = Date.now() - startMs;

      this._emit("sync:pull:complete", result);

      return result;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this._emit("sync:pull:error", { message });
      throw err;
    }
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  private _emit(type: string, data: unknown): void {
    this.eventService?.broadcast({ type: type as import("../types").ActivityEventType, data });
  }
}
