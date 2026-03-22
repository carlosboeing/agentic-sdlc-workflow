import { Database } from "bun:sqlite";
import { drizzle } from "drizzle-orm/bun-sqlite";
import * as schema from "./schema";

/**
 * Create a Drizzle database connection with WAL mode, foreign keys, and busy
 * timeout enabled.  Accepts either a file path or ":memory:" for tests.
 *
 * Returns both the raw `bun:sqlite` Database handle (for PRAGMA queries and
 * lifecycle management) and the Drizzle wrapper.
 */
export function createDatabase(path: string): {
  db: ReturnType<typeof drizzle>;
  sqlite: Database;
} {
  const sqlite = new Database(path);

  // Enable WAL mode for concurrent read access while writing
  sqlite.run("PRAGMA journal_mode = WAL");
  // Enforce referential integrity
  sqlite.run("PRAGMA foreign_keys = ON");
  // Avoid SQLITE_BUSY when the write lock is briefly held
  sqlite.run("PRAGMA busy_timeout = 5000");

  const db = drizzle(sqlite, { schema });

  return { db, sqlite };
}

/**
 * Gracefully close a database connection.  Runs a WAL checkpoint first to
 * ensure all data is flushed to the main database file (important before
 * daemon shutdown).
 */
export function closeDatabase(sqlite: Database): void {
  try {
    sqlite.run("PRAGMA wal_checkpoint(TRUNCATE)");
  } catch {
    // Checkpoint may fail on :memory: or already-closed connections
  }
  sqlite.close();
}
