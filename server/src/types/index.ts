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

/** Sync queue operation types. */
export type SyncOperation =
  | "create"
  | "update"
  | "close"
  | "comment"
  | "set_status"
  | "link_child";

/** Sync queue entry status. */
export type SyncStatus =
  | "pending"
  | "in_flight"
  | "success"
  | "failed"
  | "dead_letter";

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

/** Agent roles that can create or modify items. */
export type AgentRole =
  | "designer"
  | "planner"
  | "builder"
  | "reviewer"
  | "orchestrator"
  | "retro"
  | "human";
