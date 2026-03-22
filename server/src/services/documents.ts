import { resolve, join, relative, basename, extname } from "node:path";
import { readdirSync, readFileSync, existsSync, statSync } from "node:fs";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** A file entry returned by listFiles(). */
export interface DocumentEntry {
  /** Relative path from the docs root (e.g., "design/overview.md"). */
  path: string;
  /** Display name (filename without directory prefix). */
  name: string;
}

// ---------------------------------------------------------------------------
// DocumentService
// ---------------------------------------------------------------------------

/**
 * Service for reading markdown files from a docs directory on disk.
 *
 * Files are never stored in the database — only comments about documents are.
 * This service handles:
 * - Recursive listing of markdown files
 * - Reading file content by relative path
 * - Path safety validation (prevents traversal attacks)
 *
 * The docsDir is injected at construction time so tests can pass a temporary
 * directory without touching the real repo docs/.
 */
export class DocumentService {
  constructor(private readonly docsDir: string) {}

  /**
   * Recursively list all .md files under docsDir.
   * Returns relative paths from docsDir root.
   */
  async listFiles(): Promise<DocumentEntry[]> {
    const entries: DocumentEntry[] = [];
    this._walkDir(this.docsDir, this.docsDir, entries);
    // Sort alphabetically by path for stable ordering
    entries.sort((a, b) => a.path.localeCompare(b.path));
    return entries;
  }

  /**
   * Read a markdown file by its relative path.
   * Returns null when the file does not exist.
   * Throws if the path is unsafe (traversal detected).
   */
  async readFile(relPath: string): Promise<string | null> {
    const absPath = resolve(join(this.docsDir, relPath));

    // Verify the resolved path is still under docsDir
    if (!absPath.startsWith(this.docsDir + "/") && absPath !== this.docsDir) {
      throw new Error("Path traversal detected");
    }

    if (!existsSync(absPath)) {
      return null;
    }

    const stat = statSync(absPath);
    if (!stat.isFile()) {
      return null;
    }

    return readFileSync(absPath, "utf-8");
  }

  /**
   * Check whether a relative path is safe to use.
   *
   * A path is safe when:
   * - It does not start with / (absolute paths are rejected)
   * - It does not contain .. segments (traversal is rejected)
   * - After joining with docsDir and resolving, it stays under docsDir
   *
   * This is exposed as a public method so route handlers can validate
   * before doing any file I/O.
   */
  isPathSafe(relPath: string): boolean {
    // Reject absolute paths
    if (relPath.startsWith("/")) {
      return false;
    }

    // Reject paths containing .. (includes encoded variants after decode)
    const decoded = decodeURIComponent(relPath);
    if (decoded.includes("..")) {
      return false;
    }

    // Final check: resolve and verify the resulting path is under docsDir
    try {
      const absPath = resolve(join(this.docsDir, decoded));
      return (
        absPath.startsWith(this.docsDir + "/") || absPath === this.docsDir
      );
    } catch {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  private _walkDir(
    dir: string,
    rootDir: string,
    entries: DocumentEntry[]
  ): void {
    let items: string[];
    try {
      items = readdirSync(dir);
    } catch {
      return; // Directory not readable — skip silently
    }

    for (const item of items) {
      const absItem = join(dir, item);
      let stat;
      try {
        stat = statSync(absItem);
      } catch {
        continue;
      }

      if (stat.isDirectory()) {
        this._walkDir(absItem, rootDir, entries);
      } else if (stat.isFile() && extname(item).toLowerCase() === ".md") {
        const relPath = relative(rootDir, absItem);
        entries.push({
          path: relPath,
          name: basename(item),
        });
      }
    }
  }
}
