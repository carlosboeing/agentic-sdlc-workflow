/**
 * Frontend TypeScript types — mirror the server's types/index.ts.
 *
 * These are used by the API client and React components to type
 * data received from or sent to the server API.
 *
 * IMPORTANT: The API returns camelCase field names (from Drizzle ORM).
 * All interfaces here must use camelCase to match.
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
  | "sync:pull:started"
  | "sync:pull:progress"
  | "sync:pull:complete"
  | "sync:pull:error"
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
// API response shapes (camelCase — matches Drizzle ORM serialization)
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
  parentId: number | null;
  externalId: string | null;
  externalUrl: string | null;
  createdBy: AgentRole | null;
  createdAt: string;
  updatedAt: string;
  labels?: Label[];
}

export interface Comment {
  id: number;
  itemId: number | null;
  documentPath: string | null;
  anchor: string | null;
  body: string;
  author: string;
  threadId: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface TelemetryRecord {
  id: number;
  itemId: number;
  model: TelemetryModel;
  durationMs: number;
  tokens: number;
  toolUses: number | null;
  costEstimate: number | null;
  commitHash: string | null;
  metadata: string | null;
  createdAt: string;
}

export interface ActivityEvent {
  id: number;
  itemId: number | null;
  eventType: ActivityEventType;
  payload: string;
  createdAt: string;
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
  parentId?: number;
  labels?: string[];
}

export interface UpdateItemPayload {
  title?: string;
  body?: string;
}

export interface SetStatusPayload {
  status: BoardStatus;
}
