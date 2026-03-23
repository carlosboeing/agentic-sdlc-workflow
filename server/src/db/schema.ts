import {
  sqliteTable,
  text,
  integer,
  real,
  primaryKey,
  type AnySQLiteColumn,
} from "drizzle-orm/sqlite-core";
import { relations } from "drizzle-orm";

// -- items ------------------------------------------------------------------

export const items = sqliteTable("items", {
  id: integer("id").primaryKey(),
  title: text("title").notNull(),
  type: text("type", {
    enum: ["backlog", "epic", "story", "docs"],
  }).notNull(),
  status: text("status", {
    enum: ["backlog", "ready", "in-progress", "in-review", "done"],
  }).notNull(),
  state: text("state", {
    enum: ["open", "closed"],
  }).notNull(),
  body: text("body"),
  parentId: integer("parent_id").references((): AnySQLiteColumn => items.id),
  externalId: text("external_id"),
  externalUrl: text("external_url"),
  createdBy: text("created_by"),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const itemsRelations = relations(items, ({ one, many }) => ({
  parent: one(items, {
    fields: [items.parentId],
    references: [items.id],
    relationName: "parentChild",
  }),
  children: many(items, { relationName: "parentChild" }),
  labels: many(itemLabels),
  comments: many(comments),
  telemetry: many(telemetry),
  activityLog: many(activityLog),
}));

// -- labels -----------------------------------------------------------------

export const labels = sqliteTable("labels", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  name: text("name").notNull().unique(),
  color: text("color"),
  description: text("description"),
});

export const labelsRelations = relations(labels, ({ many }) => ({
  items: many(itemLabels),
}));

// -- item_labels (junction table) -------------------------------------------

export const itemLabels = sqliteTable(
  "item_labels",
  {
    itemId: integer("item_id")
      .notNull()
      .references(() => items.id),
    labelId: integer("label_id")
      .notNull()
      .references(() => labels.id),
  },
  (table) => [primaryKey({ columns: [table.itemId, table.labelId] })]
);

export const itemLabelsRelations = relations(itemLabels, ({ one }) => ({
  item: one(items, {
    fields: [itemLabels.itemId],
    references: [items.id],
  }),
  label: one(labels, {
    fields: [itemLabels.labelId],
    references: [labels.id],
  }),
}));

// -- comments ---------------------------------------------------------------

export const comments = sqliteTable("comments", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  itemId: integer("item_id").references(() => items.id),
  documentPath: text("document_path"),
  anchor: text("anchor"),
  body: text("body").notNull(),
  author: text("author").notNull(),
  threadId: text("thread_id"),
  createdAt: text("created_at").notNull(),
  updatedAt: text("updated_at").notNull(),
});

export const commentsRelations = relations(comments, ({ one }) => ({
  item: one(items, {
    fields: [comments.itemId],
    references: [items.id],
  }),
}));

// -- telemetry --------------------------------------------------------------

export const telemetry = sqliteTable("telemetry", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  itemId: integer("item_id")
    .notNull()
    .references(() => items.id),
  model: text("model", {
    enum: ["haiku", "sonnet", "opus", "mixed"],
  }).notNull(),
  durationMs: integer("duration_ms").notNull(),
  tokens: integer("tokens").notNull(),
  toolUses: integer("tool_uses"),
  costEstimate: real("cost_estimate"),
  commitHash: text("commit_hash"),
  metadata: text("metadata"),
  createdAt: text("created_at").notNull(),
});

export const telemetryRelations = relations(telemetry, ({ one }) => ({
  item: one(items, {
    fields: [telemetry.itemId],
    references: [items.id],
  }),
}));

// -- sync_queue -------------------------------------------------------------

export const syncQueue = sqliteTable("sync_queue", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  operation: text("operation", {
    enum: ["create", "update", "close", "comment", "set_status", "link_child"],
  }).notNull(),
  payload: text("payload").notNull(),
  status: text("status", {
    enum: ["pending", "in_flight", "success", "failed", "dead_letter"],
  }).notNull(),
  retryCount: integer("retry_count").notNull().default(0),
  lastError: text("last_error"),
  idempotencyKey: text("idempotency_key"),
  itemId: integer("item_id"),
  createdAt: text("created_at").notNull(),
  processedAt: text("processed_at"),
});

// -- activity_log -----------------------------------------------------------

export const activityLog = sqliteTable("activity_log", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  itemId: integer("item_id").references(() => items.id),
  eventType: text("event_type").notNull(),
  payload: text("payload").notNull(),
  createdAt: text("created_at").notNull(),
});

export const activityLogRelations = relations(activityLog, ({ one }) => ({
  item: one(items, {
    fields: [activityLog.itemId],
    references: [items.id],
  }),
}));
