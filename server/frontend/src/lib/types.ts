/**
 * Frontend TypeScript types — mirror the server's types/index.ts.
 *
 * These are used by the API client and React components to type
 * data received from or sent to the server API.
 */

/** Work item hierarchy types — exactly three levels. */
export type ItemType = "backlog" | "epic" | "story" | "docs";

/** Board status values matching GitHub project board columns. */
export type BoardStatus =
  | "backlog"
  | "ready"
  | "in-progress"
  | "in-review"
  | "done";

/** Item open/closed state. */
export type ItemState = "open" | "closed";

/** Telemetry model identifiers. */
export type TelemetryModel = "haiku" | "sonnet" | "opus" | "mixed";

/** Activity log event types. */
export type ActivityEventType =
  | "item:created"
  | "item:updated"
  | "item:closed"
  | "status:changed"
  | "comment:added"
  | "comment:updated"
  | "telemetry:posted"
  | "label:added"
  | "label:removed"
  | "child:linked"
  | "child:unlinked"
  | "sync:queued"
  | "sync:completed"
  | "sync:failed"
  | "server:started"
  | "server:stopped";

/** Agent roles. */
export type AgentRole =
  | "designer"
  | "planner"
  | "builder"
  | "reviewer"
  | "orchestrator"
  | "retro"
  | "human";

// ---------------------------------------------------------------------------
// API response shapes
// ---------------------------------------------------------------------------

export interface Label {
  id: number;
  name: string;
  color: string | null;
  description: string | null;
}

export interface WorkItem {
  id: number;
  title: string;
  type: ItemType;
  status: BoardStatus;
  state: ItemState;
  body: string | null;
  parent_id: number | null;
  external_id: string | null;
  external_url: string | null;
  created_by: AgentRole | null;
  created_at: string;
  updated_at: string;
  labels?: Label[];
}

export interface Comment {
  id: number;
  item_id: number | null;
  document_path: string | null;
  anchor: string | null;
  body: string;
  author: string;
  thread_id: string | null;
  created_at: string;
  updated_at: string;
}

export interface TelemetryRecord {
  id: number;
  item_id: number;
  model: TelemetryModel;
  duration_ms: number;
  tokens: number;
  tool_uses: number | null;
  cost_estimate: number | null;
  commit_hash: string | null;
  metadata: string | null;
  created_at: string;
}

export interface ActivityEvent {
  id: number;
  item_id: number | null;
  event_type: ActivityEventType;
  payload: string;
  created_at: string;
}

export interface HealthResponse {
  status: "ok";
  uptime: number;
}

export interface ApiError {
  error: string;
  details?: unknown;
}

// ---------------------------------------------------------------------------
// WebSocket event messages
// ---------------------------------------------------------------------------

export interface WsMessage<T = unknown> {
  type: ActivityEventType;
  data: T;
}

export interface WsItemStatusChanged {
  itemId: number;
  oldStatus: BoardStatus;
  newStatus: BoardStatus;
  timestamp: string;
}

// ---------------------------------------------------------------------------
// Document types
// ---------------------------------------------------------------------------

/** A file entry returned by GET /api/documents. */
export interface DocumentEntry {
  /** Relative path from docs root (e.g., "design/overview.md"). */
  path: string;
  /** Display name (filename). */
  name: string;
}

/** Full document content returned by GET /api/documents/:path. */
export interface DocumentContent {
  /** Relative path from docs root. */
  path: string;
  /** Filename only. */
  name: string;
  /** Raw markdown content. */
  content: string;
}

// ---------------------------------------------------------------------------
// Query / filter params
// ---------------------------------------------------------------------------

export interface ListItemsParams {
  type?: ItemType;
  status?: BoardStatus;
  state?: ItemState;
  label?: string;
  limit?: number;
}

// ---------------------------------------------------------------------------
// Create / update payloads
// ---------------------------------------------------------------------------

export interface CreateItemPayload {
  type: ItemType;
  title: string;
  body?: string;
  parent_id?: number;
  labels?: string[];
}

export interface UpdateItemPayload {
  title?: string;
  body?: string;
}

export interface SetStatusPayload {
  status: BoardStatus;
}
