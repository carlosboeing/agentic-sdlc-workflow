import { existsSync, readFileSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import type { Hono } from "hono";
import type { drizzle } from "drizzle-orm/bun-sqlite";
import { ItemService } from "../services/items";
import { LabelService } from "../services/labels";
import { BoardService } from "../services/board";
import { CommentService } from "../services/comments";
import { HierarchyService } from "../services/hierarchy";
import { LifecycleService } from "../services/lifecycle";
import { DocumentService } from "../services/documents";
import { EventService, createActivityRouter } from "./websocket";
import { createItemsRouter } from "./items";
import { createBoardRouter } from "./board";
import { createCommentsRouter } from "./comments";
import { createHierarchyRouter } from "./hierarchy";
import { createTelemetryRouter } from "./telemetry";
import { createSyncRouter } from "./sync";
import { GitHubPullFetcher } from "../adapters/github-pull";
import { PullSyncService } from "../services/pull-sync";
import { IssueMapper } from "../lib/issue-mapper";
import { DatabaseUpserter } from "../services/database-upserter";
import { createDocumentsRouter } from "./documents";

type Db = ReturnType<typeof drizzle>;

/**
 * Read the `github.repo` field from `.claude/agentic-sdlc-config.json`.
 * Falls back to an empty string when the file is absent or malformed,
 * so the route is still registered (PullSyncService will fail at runtime
 * if no valid repo is configured, which is the correct behavior).
 */
function readGithubRepo(): string {
  // routes.ts lives at server/src/api/routes.ts
  // Repo root is 3 directories up: api/ → src/ → server/ → <repo-root>
  const repoRoot = resolve(dirname(new URL(import.meta.url).pathname), "../../..");
  const configPath = join(repoRoot, ".claude", "agentic-sdlc-config.json");
  if (!existsSync(configPath)) return "";
  try {
    const raw = readFileSync(configPath, "utf8");
    const parsed = JSON.parse(raw) as { github?: { repo?: string } };
    return parsed.github?.repo ?? "";
  } catch {
    return "";
  }
}

/**
 * Mount all API route groups onto the provided Hono app.
 *
 * This is the single registration point for all routes.
 * Each route group is created with the appropriate services.
 *
 * Route groups:
 *   items.ts     — /api/items CRUD (E02-S01)
 *   board.ts     — /api/items/:id/status (E02-S02)
 *   comments.ts  — /api/items/:id/comments (E02-S02)
 *   hierarchy.ts — /api/items/:id/children (E02-S02)
 *   telemetry.ts — /api/items/:id/telemetry + start + complete (E02-S02)
 *   websocket.ts — /api/activity feed endpoint (E05-S04)
 *   sync.ts      — /api/sync/pull and /api/sync/status (E02-S01)
 *   documents.ts — /api/documents list + read + comments (E06-S01)
 *
 * @param app          - The Hono application instance
 * @param db           - Drizzle DB connection shared by all route groups
 * @param eventService - Optional EventService for real-time broadcasts.
 *                       When omitted, services run without WebSocket events.
 * @param githubRepo   - Optional GitHub repo override ("owner/repo").
 *                       When omitted, read from agentic-sdlc-config.json.
 * @param repoRoot     - Absolute path to the repository root.
 *                       Used to resolve the docs/ directory for document serving.
 *                       Defaults to 3 levels above this file (server/src/api/ → repo root).
 */
export function registerRoutes(
  app: Hono,
  db: Db,
  eventService?: EventService,
  githubRepo?: string,
  repoRoot?: string
): void {
  const effectiveEventService = eventService ?? new EventService(db);
  const itemService = new ItemService(db, effectiveEventService);
  const labelService = new LabelService(db);
  const boardService = new BoardService(db, effectiveEventService);
  const commentService = new CommentService(db, effectiveEventService);
  const hierarchyService = new HierarchyService(db);
  const lifecycleService = new LifecycleService(db, effectiveEventService);

  // Resolve docs directory — defaults to <repo-root>/docs/
  // routes.ts is at server/src/api/routes.ts; repo root is 3 dirs up
  const resolvedRepoRoot =
    repoRoot ?? resolve(new URL(import.meta.url).pathname, "../../../..");
  const docsDir = join(resolvedRepoRoot, "docs");
  const documentService = new DocumentService(docsDir);

  // Item CRUD + label management (E02-S01)
  app.route("/api", createItemsRouter(itemService, labelService, db));

  // Board status transitions (E02-S02)
  app.route("/api", createBoardRouter(boardService));

  // Item comments (E02-S02)
  app.route("/api", createCommentsRouter(commentService, itemService));

  // Parent-child hierarchy (E02-S02)
  app.route("/api", createHierarchyRouter(hierarchyService, itemService));

  // Lifecycle (start/complete) + telemetry (E02-S02)
  app.route("/api", createTelemetryRouter(lifecycleService, itemService));

  // Activity feed REST endpoint (E05-S04)
  app.route("/api", createActivityRouter(effectiveEventService));

  // Pull sync endpoint (BL364 E02-S01)
  const repo = githubRepo ?? readGithubRepo();
  const fetcher = new GitHubPullFetcher({ repo });
  const mapper = new IssueMapper();
  const upserter = new DatabaseUpserter(db);
  const pullSyncService = new PullSyncService(fetcher, mapper, upserter, effectiveEventService);
  app.route("/api", createSyncRouter(pullSyncService));
  // Document file list + read + comments (E06-S01)
  app.route("/api", createDocumentsRouter(documentService, commentService));
}
