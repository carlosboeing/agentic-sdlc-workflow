/**
 * GitHub external adapter for the sync engine.
 *
 * Implements ExternalPmAdapter by mapping each sync operation to the
 * appropriate `gh` CLI command or GitHub GraphQL API call.
 *
 * All subprocess calls go through `_runGh()` so tests can spy on a single
 * point without patching global process spawning.
 */

import type {
  ExternalPmAdapter,
  SyncCreatePayload,
  SyncUpdatePayload,
  SyncClosePayload,
  SyncSetStatusPayload,
  SyncCommentPayload,
  SyncLinkChildPayload,
} from "../types/sync";
import type { BoardStatus } from "../types";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

/**
 * Configuration required by GitHubAdapter.
 * Mirrors the relevant fields from `.claude/agentic-sdlc-config.json`.
 */
export interface GitHubAdapterConfig {
  /** GitHub repository in "owner/repo" format. */
  repo: string;
  /** GitHub Projects v2 project node ID (e.g. "PVT_kwHO…"). */
  projectId: string;
  /** Status field ID for the project (e.g. "PVTSSF_lAHO…"). */
  statusFieldId: string;
  /** Map from BoardStatus value to GitHub project option ID. */
  boardStatus: Record<BoardStatus, string>;
}

// ---------------------------------------------------------------------------
// Subprocess result
// ---------------------------------------------------------------------------

/** Minimal result type returned by _runGh(). */
interface GhResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

// ---------------------------------------------------------------------------
// GitHubAdapter
// ---------------------------------------------------------------------------

/**
 * Implements ExternalPmAdapter by delegating to the `gh` CLI.
 *
 * Method summary:
 *   createItem   → `gh issue create`
 *   updateItem   → `gh issue edit`
 *   closeItem    → `gh issue close`
 *   setStatus    → GraphQL query for board item ID + `gh project item-edit`
 *   addComment   → `gh issue comment`
 *   linkChild    → `gh issue view --json id` x2 + GraphQL addSubIssue mutation
 */
export class GitHubAdapter implements ExternalPmAdapter {
  constructor(private readonly config: GitHubAdapterConfig) {}

  // -------------------------------------------------------------------------
  // createItem
  // -------------------------------------------------------------------------

  async createItem(payload: SyncCreatePayload): Promise<{ externalId: string; url: string }> {
    const args = [
      "issue",
      "create",
      "--repo",
      this.config.repo,
      "--title",
      payload.title,
    ];

    if (payload.body) {
      args.push("--body", payload.body);
    } else {
      args.push("--body", "");
    }

    if (payload.labels && payload.labels.length > 0) {
      args.push("--label", payload.labels.join(","));
    }

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `gh issue create failed (exit ${result.exitCode}): ${result.stderr.trim()}`
      );
    }

    const url = result.stdout.trim();
    const match = url.match(/\/(\d+)$/);
    if (!match) {
      throw new Error(`Could not extract issue number from gh output: "${url}"`);
    }

    return { externalId: match[1], url };
  }

  // -------------------------------------------------------------------------
  // updateItem
  // -------------------------------------------------------------------------

  async updateItem(payload: SyncUpdatePayload): Promise<void> {
    const args = ["issue", "edit", payload.externalId, "--repo", this.config.repo];

    if (payload.changes.title !== undefined) {
      args.push("--title", payload.changes.title);
    }

    if (payload.changes.body !== undefined) {
      args.push("--body", payload.changes.body);
    }

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `gh issue edit failed (exit ${result.exitCode}): ${result.stderr.trim()}`
      );
    }
  }

  // -------------------------------------------------------------------------
  // closeItem
  // -------------------------------------------------------------------------

  async closeItem(payload: SyncClosePayload): Promise<void> {
    const args = ["issue", "close", payload.externalId, "--repo", this.config.repo];

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `gh issue close failed (exit ${result.exitCode}): ${result.stderr.trim()}`
      );
    }
  }

  // -------------------------------------------------------------------------
  // setStatus
  // -------------------------------------------------------------------------

  async setStatus(payload: SyncSetStatusPayload): Promise<void> {
    // Step 1: Fetch the project item node ID via lightweight GraphQL query.
    const [repoOwner, repoName] = this.config.repo.split("/");
    const queryArgs = [
      "api",
      "graphql",
      "-f",
      `query=query {
  repository(owner: "${repoOwner}", name: "${repoName}") {
    issue(number: ${payload.externalId}) {
      projectItems(first: 1) {
        nodes { id }
      }
    }
  }
}`,
    ];

    const queryResult = await this._runGh(queryArgs);

    if (queryResult.exitCode !== 0) {
      throw new Error(
        `Failed to fetch project item for issue #${payload.externalId}: ${queryResult.stderr.trim()}`
      );
    }

    let projectItemId: string;
    try {
      const parsed = JSON.parse(queryResult.stdout);
      const nodes: Array<{ id: string }> =
        parsed?.data?.repository?.issue?.projectItems?.nodes ?? [];
      if (nodes.length === 0) {
        throw new Error(
          `Issue #${payload.externalId} not found on project board`
        );
      }
      projectItemId = nodes[0].id;
    } catch (err) {
      if (err instanceof SyntaxError) {
        throw new Error(
          `Failed to parse GraphQL response for issue #${payload.externalId}: ${queryResult.stdout}`
        );
      }
      throw err;
    }

    // Step 2: Look up the option ID for the target status.
    const optionId = this.config.boardStatus[payload.status];
    if (!optionId) {
      throw new Error(`Unknown board status: "${payload.status}"`);
    }

    // Step 3: Mutate the project item status.
    const editArgs = [
      "project",
      "item-edit",
      "--project-id",
      this.config.projectId,
      "--id",
      projectItemId,
      "--field-id",
      this.config.statusFieldId,
      "--single-select-option-id",
      optionId,
    ];

    const editResult = await this._runGh(editArgs);

    if (editResult.exitCode !== 0) {
      throw new Error(
        `gh project item-edit failed (exit ${editResult.exitCode}): ${editResult.stderr.trim()}`
      );
    }
  }

  // -------------------------------------------------------------------------
  // addComment
  // -------------------------------------------------------------------------

  async addComment(payload: SyncCommentPayload): Promise<void> {
    const args = [
      "issue",
      "comment",
      payload.externalId,
      "--repo",
      this.config.repo,
      "--body",
      payload.body,
    ];

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `gh issue comment failed (exit ${result.exitCode}): ${result.stderr.trim()}`
      );
    }
  }

  // -------------------------------------------------------------------------
  // linkChild
  // -------------------------------------------------------------------------

  async linkChild(payload: SyncLinkChildPayload): Promise<void> {
    // Step 1: Fetch parent issue node ID.
    const parentNodeId = await this._fetchIssueNodeId(payload.parentExternalId);

    // Step 2: Fetch child issue node ID.
    const childNodeId = await this._fetchIssueNodeId(payload.childExternalId);

    // Step 3: Call addSubIssue GraphQL mutation.
    const mutationArgs = [
      "api",
      "graphql",
      "-f",
      `query=mutation {
  addSubIssue(input: { issueId: "${parentNodeId}", subIssueId: "${childNodeId}" }) {
    subIssue { id }
  }
}`,
    ];

    const mutationResult = await this._runGh(mutationArgs);

    if (mutationResult.exitCode !== 0) {
      throw new Error(
        `addSubIssue mutation failed for #${payload.childExternalId} → #${payload.parentExternalId}: ${mutationResult.stderr.trim()}`
      );
    }
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  /**
   * Fetch the GitHub node ID for an issue by number.
   * Uses `gh issue view <number> --json id`.
   */
  private async _fetchIssueNodeId(issueNumber: string): Promise<string> {
    const args = [
      "issue",
      "view",
      issueNumber,
      "--repo",
      this.config.repo,
      "--json",
      "id",
    ];

    const result = await this._runGh(args);

    if (result.exitCode !== 0) {
      throw new Error(
        `Could not fetch node ID for issue #${issueNumber}: ${result.stderr.trim()}`
      );
    }

    try {
      const parsed = JSON.parse(result.stdout);
      const nodeId = parsed?.id;
      if (!nodeId) {
        throw new Error(`Missing id field in gh issue view response for #${issueNumber}`);
      }
      return nodeId as string;
    } catch (err) {
      if (err instanceof SyntaxError) {
        throw new Error(
          `Could not fetch node ID for issue #${issueNumber}: invalid JSON response`
        );
      }
      throw err;
    }
  }

  /**
   * Execute a `gh` CLI command and return stdout, stderr, and exit code.
   *
   * Extracted to a method so tests can spy on it without patching globals.
   * Using Bun.spawn for subprocess execution.
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

    return {
      stdout: stdoutBuf,
      stderr: stderrBuf,
      exitCode,
    };
  }
}
