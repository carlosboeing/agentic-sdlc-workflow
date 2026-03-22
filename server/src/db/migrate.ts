import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { createDatabase, closeDatabase } from "./connection";

const dbPath =
  process.env.WORKFLOW_DB_PATH ?? ".agentic-workflow/workflow.db";

console.error(`[migrate] Database path: ${dbPath}`);
console.error(`[migrate] Migrations folder: ./server/src/db/migrations`);

const { db, sqlite } = createDatabase(dbPath);

try {
  migrate(db, {
    migrationsFolder: "./server/src/db/migrations",
  });
  console.error("[migrate] Migrations applied successfully");
} catch (error) {
  console.error("[migrate] Migration failed:", error);
  process.exit(1);
} finally {
  closeDatabase(sqlite);
}
