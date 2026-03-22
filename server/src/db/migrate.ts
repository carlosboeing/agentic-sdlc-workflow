import { resolve, dirname } from "node:path";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { createDatabase, closeDatabase } from "./connection";

/** Resolve migration folder relative to this file, works from any cwd. */
const MIGRATIONS_FOLDER = resolve(
  dirname(new URL(import.meta.url).pathname),
  "./migrations"
);

const dbPath =
  process.env.WORKFLOW_DB_PATH ?? ".agentic-workflow/workflow.db";

console.error(`[migrate] Database path: ${dbPath}`);
console.error(`[migrate] Migrations folder: ${MIGRATIONS_FOLDER}`);

const { db, sqlite } = createDatabase(dbPath);

try {
  migrate(db, {
    migrationsFolder: MIGRATIONS_FOLDER,
  });
  console.error("[migrate] Migrations applied successfully");
} catch (error) {
  console.error("[migrate] Migration failed:", error);
  process.exit(1);
} finally {
  closeDatabase(sqlite);
}
