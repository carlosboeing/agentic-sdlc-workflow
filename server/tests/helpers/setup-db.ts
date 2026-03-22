import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import * as schema from "../../src/db/schema";

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
    migrationsFolder: "./server/src/db/migrations",
  });

  return { db, sqlite };
}
