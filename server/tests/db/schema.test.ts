import { resolve, dirname } from "node:path";
import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { sql } from "drizzle-orm";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import * as schema from "../../src/db/schema";
import { createDatabase, closeDatabase } from "../../src/db/connection";

/** Resolve migration folder relative to this file, works from any cwd. */
const MIGRATIONS_FOLDER = resolve(
  dirname(new URL(import.meta.url).pathname),
  "../../src/db/migrations"
);

describe("Database Schema", () => {
  let sqlite: Database;
  let db: ReturnType<typeof drizzle>;

  beforeEach(() => {
    sqlite = new Database(":memory:");
    db = drizzle(sqlite, { schema });
    migrate(db, {
      migrationsFolder: MIGRATIONS_FOLDER,
    });
  });

  afterEach(() => {
    sqlite.close();
  });

  describe("Table creation", () => {
    test("creates all 7 expected tables", () => {
      const tables = sqlite
        .query(
          "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '__drizzle%' ORDER BY name"
        )
        .all() as { name: string }[];

      const tableNames = tables.map((t) => t.name).sort();

      expect(tableNames).toContain("items");
      expect(tableNames).toContain("labels");
      expect(tableNames).toContain("item_labels");
      expect(tableNames).toContain("comments");
      expect(tableNames).toContain("telemetry");
      expect(tableNames).toContain("sync_queue");
      expect(tableNames).toContain("activity_log");
      expect(tableNames.length).toBeGreaterThanOrEqual(7);
    });

    test("items table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(items)")
        .all() as { name: string; type: string; notnull: number; pk: number }[];

      const colMap = new Map(columns.map((c) => [c.name, c]));

      expect(colMap.has("id")).toBe(true);
      expect(colMap.get("id")!.pk).toBe(1);

      expect(colMap.has("title")).toBe(true);
      expect(colMap.has("type")).toBe(true);
      expect(colMap.has("status")).toBe(true);
      expect(colMap.has("state")).toBe(true);
      expect(colMap.has("body")).toBe(true);
      expect(colMap.has("parent_id")).toBe(true);
      expect(colMap.has("external_id")).toBe(true);
      expect(colMap.has("external_url")).toBe(true);
      expect(colMap.has("created_by")).toBe(true);
      expect(colMap.has("created_at")).toBe(true);
      expect(colMap.has("updated_at")).toBe(true);
    });

    test("labels table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(labels)")
        .all() as { name: string }[];

      const colNames = columns.map((c) => c.name);

      expect(colNames).toContain("id");
      expect(colNames).toContain("name");
      expect(colNames).toContain("color");
      expect(colNames).toContain("description");
    });

    test("item_labels table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(item_labels)")
        .all() as { name: string }[];

      const colNames = columns.map((c) => c.name);

      expect(colNames).toContain("item_id");
      expect(colNames).toContain("label_id");
    });

    test("comments table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(comments)")
        .all() as { name: string }[];

      const colNames = columns.map((c) => c.name);

      expect(colNames).toContain("id");
      expect(colNames).toContain("item_id");
      expect(colNames).toContain("document_path");
      expect(colNames).toContain("anchor");
      expect(colNames).toContain("body");
      expect(colNames).toContain("author");
      expect(colNames).toContain("thread_id");
      expect(colNames).toContain("created_at");
      expect(colNames).toContain("updated_at");
    });

    test("telemetry table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(telemetry)")
        .all() as { name: string }[];

      const colNames = columns.map((c) => c.name);

      expect(colNames).toContain("id");
      expect(colNames).toContain("item_id");
      expect(colNames).toContain("model");
      expect(colNames).toContain("duration_ms");
      expect(colNames).toContain("tokens");
      expect(colNames).toContain("tool_uses");
      expect(colNames).toContain("cost_estimate");
      expect(colNames).toContain("commit_hash");
      expect(colNames).toContain("metadata");
      expect(colNames).toContain("created_at");
    });

    test("sync_queue table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(sync_queue)")
        .all() as { name: string }[];

      const colNames = columns.map((c) => c.name);

      expect(colNames).toContain("id");
      expect(colNames).toContain("operation");
      expect(colNames).toContain("payload");
      expect(colNames).toContain("status");
      expect(colNames).toContain("retry_count");
      expect(colNames).toContain("last_error");
      expect(colNames).toContain("created_at");
      expect(colNames).toContain("processed_at");
    });

    test("activity_log table has correct columns", () => {
      const columns = sqlite
        .query("PRAGMA table_info(activity_log)")
        .all() as { name: string }[];

      const colNames = columns.map((c) => c.name);

      expect(colNames).toContain("id");
      expect(colNames).toContain("item_id");
      expect(colNames).toContain("event_type");
      expect(colNames).toContain("payload");
      expect(colNames).toContain("created_at");
    });
  });

  describe("Insert and select round-trips", () => {
    test("items: insert and select", () => {
      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test Item",
        type: "story",
        status: "backlog",
        state: "open",
        body: "Test body",
        createdAt: now,
        updatedAt: now,
      }).run();

      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].title).toBe("Test Item");
      expect(rows[0].type).toBe("story");
      expect(rows[0].status).toBe("backlog");
      expect(rows[0].state).toBe("open");
    });

    test("labels: insert and select", () => {
      db.insert(schema.labels).values({
        name: "difficulty/hard",
        color: "#ff0000",
        description: "Hard difficulty",
      }).run();

      const rows = db.select().from(schema.labels).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].name).toBe("difficulty/hard");
      expect(rows[0].color).toBe("#ff0000");
    });

    test("item_labels: insert and select with valid foreign keys", () => {
      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test Item",
        type: "story",
        status: "backlog",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      db.insert(schema.labels).values({
        id: 1,
        name: "hierarchy/story",
      }).run();

      db.insert(schema.itemLabels).values({
        itemId: 1,
        labelId: 1,
      }).run();

      const rows = db.select().from(schema.itemLabels).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].itemId).toBe(1);
      expect(rows[0].labelId).toBe(1);
    });

    test("comments: insert and select", () => {
      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test Item",
        type: "story",
        status: "backlog",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      db.insert(schema.comments).values({
        itemId: 1,
        body: "Test comment",
        author: "builder",
        createdAt: now,
        updatedAt: now,
      }).run();

      const rows = db.select().from(schema.comments).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].body).toBe("Test comment");
      expect(rows[0].author).toBe("builder");
    });

    test("telemetry: insert and select", () => {
      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test Item",
        type: "story",
        status: "backlog",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      db.insert(schema.telemetry).values({
        itemId: 1,
        model: "opus",
        durationMs: 120000,
        tokens: 50000,
        toolUses: 25,
        costEstimate: 1.50,
        commitHash: "abc123",
        metadata: JSON.stringify({ breakdown: "test" }),
        createdAt: now,
      }).run();

      const rows = db.select().from(schema.telemetry).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].model).toBe("opus");
      expect(rows[0].durationMs).toBe(120000);
      expect(rows[0].tokens).toBe(50000);
      expect(rows[0].costEstimate).toBe(1.50);
    });

    test("sync_queue: insert and select", () => {
      const now = new Date().toISOString();
      db.insert(schema.syncQueue).values({
        operation: "create",
        payload: JSON.stringify({ title: "Test" }),
        status: "pending",
        retryCount: 0,
        createdAt: now,
      }).run();

      const rows = db.select().from(schema.syncQueue).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].operation).toBe("create");
      expect(rows[0].status).toBe("pending");
      expect(rows[0].retryCount).toBe(0);
    });

    test("activity_log: insert and select", () => {
      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test Item",
        type: "story",
        status: "backlog",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      db.insert(schema.activityLog).values({
        itemId: 1,
        eventType: "item:created",
        payload: JSON.stringify({ title: "Test Item" }),
        createdAt: now,
      }).run();

      const rows = db.select().from(schema.activityLog).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].eventType).toBe("item:created");
    });
  });

  describe("Foreign key constraints", () => {
    test("enforces foreign key on comments.item_id", () => {
      // Enable foreign keys explicitly for this in-memory DB
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      expect(() => {
        db.insert(schema.comments).values({
          itemId: 999, // non-existent item_id
          body: "Orphan comment",
          author: "test",
          createdAt: now,
          updatedAt: now,
        }).run();
      }).toThrow();
    });

    test("enforces foreign key on item_labels.item_id", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      db.insert(schema.labels).values({
        id: 1,
        name: "test-label",
      }).run();

      expect(() => {
        db.insert(schema.itemLabels).values({
          itemId: 999, // non-existent item
          labelId: 1,
        }).run();
      }).toThrow();
    });

    test("enforces foreign key on item_labels.label_id", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test",
        type: "story",
        status: "backlog",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      expect(() => {
        db.insert(schema.itemLabels).values({
          itemId: 1,
          labelId: 999, // non-existent label
        }).run();
      }).toThrow();
    });

    test("enforces foreign key on telemetry.item_id", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      expect(() => {
        db.insert(schema.telemetry).values({
          itemId: 999, // non-existent item
          model: "opus",
          durationMs: 100,
          tokens: 100,
          createdAt: now,
        }).run();
      }).toThrow();
    });

    test("enforces foreign key on activity_log.item_id", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      expect(() => {
        db.insert(schema.activityLog).values({
          itemId: 999, // non-existent item
          eventType: "test",
          payload: "{}",
          createdAt: now,
        }).run();
      }).toThrow();
    });

    test("allows null item_id on comments (document comments)", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      // Document comments have no item_id, they reference a file path
      db.insert(schema.comments).values({
        itemId: null,
        documentPath: "docs/2-design/test.md",
        anchor: "section-overview",
        body: "Great section",
        author: "reviewer",
        createdAt: now,
        updatedAt: now,
      }).run();

      const rows = db.select().from(schema.comments).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].itemId).toBeNull();
      expect(rows[0].documentPath).toBe("docs/2-design/test.md");
    });

    test("allows null item_id on activity_log", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      db.insert(schema.activityLog).values({
        itemId: null,
        eventType: "server:started",
        payload: JSON.stringify({ port: 3117 }),
        createdAt: now,
      }).run();

      const rows = db.select().from(schema.activityLog).all();
      expect(rows).toHaveLength(1);
      expect(rows[0].itemId).toBeNull();
    });
  });

  describe("Self-referential foreign key on items.parent_id", () => {
    test("allows parent_id referencing another item", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      // Create parent (backlog item)
      db.insert(schema.items).values({
        id: 100,
        title: "Backlog Item",
        type: "backlog",
        status: "in-progress",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      // Create child (epic) referencing parent
      db.insert(schema.items).values({
        id: 200,
        title: "Epic",
        type: "epic",
        status: "ready",
        state: "open",
        parentId: 100,
        createdAt: now,
        updatedAt: now,
      }).run();

      const rows = db.select().from(schema.items).all();
      expect(rows).toHaveLength(2);
      expect(rows[1].parentId).toBe(100);
    });

    test("rejects parent_id referencing non-existent item", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      expect(() => {
        db.insert(schema.items).values({
          id: 1,
          title: "Orphan",
          type: "story",
          status: "backlog",
          state: "open",
          parentId: 999, // non-existent
          createdAt: now,
          updatedAt: now,
        }).run();
      }).toThrow();
    });
  });

  describe("Unique constraints", () => {
    test("labels.name is unique", () => {
      db.insert(schema.labels).values({
        name: "unique-label",
      }).run();

      expect(() => {
        db.insert(schema.labels).values({
          name: "unique-label",
        }).run();
      }).toThrow();
    });

    test("item_labels composite primary key prevents duplicates", () => {
      sqlite.run("PRAGMA foreign_keys = ON");

      const now = new Date().toISOString();
      db.insert(schema.items).values({
        id: 1,
        title: "Test",
        type: "story",
        status: "backlog",
        state: "open",
        createdAt: now,
        updatedAt: now,
      }).run();

      db.insert(schema.labels).values({
        id: 1,
        name: "test-label",
      }).run();

      db.insert(schema.itemLabels).values({
        itemId: 1,
        labelId: 1,
      }).run();

      expect(() => {
        db.insert(schema.itemLabels).values({
          itemId: 1,
          labelId: 1,
        }).run();
      }).toThrow();
    });
  });
});

describe("Database Connection", () => {
  test("creates file-based database with WAL mode enabled", () => {
    // WAL mode only works on file-based databases, not :memory:
    const { mkdtempSync, rmSync } = require("fs");
    const { join } = require("path");
    const tmpDir = mkdtempSync(join(require("os").tmpdir(), "wal-test-"));
    const dbPath = join(tmpDir, "wal-test.db");

    const { db, sqlite } = createDatabase(dbPath);

    const result = sqlite.query("PRAGMA journal_mode").get() as {
      journal_mode: string;
    };
    expect(result.journal_mode).toBe("wal");

    closeDatabase(sqlite);
    rmSync(tmpDir, { recursive: true });
  });

  test("in-memory database reports memory journal mode (WAL not applicable)", () => {
    // In-memory databases cannot use WAL; they always report "memory".
    // The createDatabase function still issues the PRAGMA (a no-op for :memory:).
    const { db, sqlite } = createDatabase(":memory:");

    const result = sqlite.query("PRAGMA journal_mode").get() as {
      journal_mode: string;
    };
    expect(result.journal_mode).toBe("memory");

    closeDatabase(sqlite);
  });

  test("creates database with foreign keys enabled", () => {
    const { db, sqlite } = createDatabase(":memory:");

    const result = sqlite.query("PRAGMA foreign_keys").get() as {
      foreign_keys: number;
    };
    expect(result.foreign_keys).toBe(1);

    closeDatabase(sqlite);
  });

  test("creates file-based database with busy timeout set", () => {
    const { mkdtempSync, rmSync } = require("fs");
    const { join } = require("path");
    const tmpDir = mkdtempSync(join(require("os").tmpdir(), "timeout-test-"));
    const dbPath = join(tmpDir, "timeout-test.db");

    const { db, sqlite } = createDatabase(dbPath);

    const result = sqlite.query("PRAGMA busy_timeout").get() as {
      timeout: number;
    };
    expect(result.timeout).toBe(5000);

    closeDatabase(sqlite);
    rmSync(tmpDir, { recursive: true });
  });

  test("in-memory database works for testing", () => {
    const { db, sqlite } = createDatabase(":memory:");

    // Run migrations
    migrate(db, {
      migrationsFolder: MIGRATIONS_FOLDER,
    });

    // Verify tables exist
    const tables = sqlite
      .query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '__drizzle%'"
      )
      .all() as { name: string }[];

    expect(tables.length).toBeGreaterThanOrEqual(7);

    closeDatabase(sqlite);
  });

  test("file-based database persists across connections", () => {
    const { mkdtempSync } = require("fs");
    const { join } = require("path");
    const tmpDir = mkdtempSync(join(require("os").tmpdir(), "db-test-"));
    const dbPath = join(tmpDir, "test.db");

    // Create and populate
    const conn1 = createDatabase(dbPath);
    migrate(conn1.db, {
      migrationsFolder: MIGRATIONS_FOLDER,
    });

    const now = new Date().toISOString();
    conn1.db.insert(schema.items).values({
      id: 42,
      title: "Persistent Item",
      type: "backlog",
      status: "backlog",
      state: "open",
      createdAt: now,
      updatedAt: now,
    }).run();

    closeDatabase(conn1.sqlite);

    // Reopen and verify
    const conn2 = createDatabase(dbPath);
    const rows = conn2.db.select().from(schema.items).all();
    expect(rows).toHaveLength(1);
    expect(rows[0].title).toBe("Persistent Item");
    expect(rows[0].id).toBe(42);

    closeDatabase(conn2.sqlite);

    // Cleanup
    const { rmSync } = require("fs");
    rmSync(tmpDir, { recursive: true });
  });
});

describe("Migration runner", () => {
  test("migrate.ts creates all tables in fresh database", async () => {
    const { mkdtempSync, rmSync } = require("fs");
    const { join } = require("path");
    const tmpDir = mkdtempSync(join(require("os").tmpdir(), "migrate-test-"));
    const dbPath = join(tmpDir, "test.db");

    // Resolve migrate.ts relative to this file so it works from any cwd
    const migrateScript = resolve(
      dirname(new URL(import.meta.url).pathname),
      "../../src/db/migrate.ts"
    );

    // Run the migration script with the test DB path
    const proc = Bun.spawn(
      ["bun", "run", migrateScript],
      {
        env: {
          ...process.env,
          WORKFLOW_DB_PATH: dbPath,
          PATH: `${process.env.HOME}/.bun/bin:${process.env.PATH}`,
        },
        stdout: "pipe",
        stderr: "pipe",
      }
    );

    const exitCode = await proc.exited;
    const stderr = await new Response(proc.stderr).text();

    expect(exitCode).toBe(0);

    // Verify tables were created
    const sqlite = new Database(dbPath);
    const tables = sqlite
      .query(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '__drizzle%' ORDER BY name"
      )
      .all() as { name: string }[];

    const tableNames = tables.map((t) => t.name).sort();
    expect(tableNames).toContain("items");
    expect(tableNames).toContain("labels");
    expect(tableNames).toContain("item_labels");
    expect(tableNames).toContain("comments");
    expect(tableNames).toContain("telemetry");
    expect(tableNames).toContain("sync_queue");
    expect(tableNames).toContain("activity_log");

    sqlite.close();
    rmSync(tmpDir, { recursive: true });
  });
});
