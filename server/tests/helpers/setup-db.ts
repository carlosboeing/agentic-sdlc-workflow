import { resolve, dirname } from "node:path";
import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import * as schema from "../../src/db/schema";

/** Resolve migration folder relative to this file, works from any cwd. */
const MIGRATIONS_FOLDER = resolve(
  dirname(new URL(import.meta.url).pathname),
  "../../src/db/migrations"
);

/**
 * Create an in-memory SQLite database with all migrations applied.
 * Returns the Drizzle ORM instance and the raw SQLite handle.
 * Call `sqlite.close()` in afterEach to clean up.
 */
export function setupTestDb(): {
  db: ReturnType<typeof drizzle>;
  sqlite: Database;
} {
  const sqlite = new Database(":memory:");
  sqlite.run("PRAGMA foreign_keys = ON");

  const db = drizzle(sqlite, { schema });
  migrate(db, {
    migrationsFolder: MIGRATIONS_FOLDER,
  });

  return { db, sqlite };
}
