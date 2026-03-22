/**
 * Tests for the REPO_ROOT path resolution used in server/src/index.ts.
 *
 * Verifies that resolving 3 levels of ".." from server/src/index.ts
 * yields the repository root — not the grandparent (which would be the case
 * with the incorrect 4-level resolution).
 *
 * Path chain:
 *   server/src/index.ts  →  server/src/  →  server/  →  <repo-root>
 *   1 level              →  2 levels    →  3 levels
 */

import { describe, test, expect } from "bun:test";
import { resolve, join, dirname } from "node:path";

describe("REPO_ROOT path resolution", () => {
  test("resolves to repo root (3 levels up from server/src/index.ts)", () => {
    // Simulate import.meta.url for server/src/index.ts
    const fakeIndexPath = join(
      // Derive repo root from this test file: tests/ -> server/ -> repo-root
      resolve(import.meta.dirname, "../.."),
      "server",
      "src",
      "index.ts"
    );

    const resolved = resolve(fakeIndexPath, "../../..");
    const expected = resolve(import.meta.dirname, "../..");

    expect(resolved).toBe(expected);
  });

  test("4-level resolution is wrong (resolves to parent of repo root)", () => {
    const fakeIndexPath = join(
      resolve(import.meta.dirname, "../.."),
      "server",
      "src",
      "index.ts"
    );

    const wrongResolved = resolve(fakeIndexPath, "../../../..");
    const repoRoot = resolve(import.meta.dirname, "../..");

    // 4 levels goes one directory too high
    expect(wrongResolved).not.toBe(repoRoot);
    expect(wrongResolved).toBe(dirname(repoRoot));
  });

  test("resolved REPO_ROOT contains .claude directory (sanity check)", () => {
    const fakeIndexPath = join(
      resolve(import.meta.dirname, "../.."),
      "server",
      "src",
      "index.ts"
    );

    const repoRoot = resolve(fakeIndexPath, "../../..");

    // The repo root must contain the .claude directory (convention enforcement)
    const { existsSync } = require("node:fs");
    expect(existsSync(join(repoRoot, ".claude"))).toBe(true);
  });
});
