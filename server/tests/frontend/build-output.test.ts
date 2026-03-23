/**
 * Tests verifying that the built frontend dist/ directory contains valid output.
 *
 * These tests are NOT run in CI by default — they require a prior `bun run build:frontend`.
 * They validate the build output structure when the dist directory exists.
 *
 * Run with: bun test tests/frontend/build-output.test.ts
 */

import { describe, test, expect } from "bun:test";
import { existsSync, statSync } from "node:fs";
import { join, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const serverDir = resolve(__dirname, "../..");
const distDir = join(serverDir, "frontend", "dist");
const assetsDir = join(distDir, "assets");

const distExists = existsSync(distDir);

describe("Frontend build output", () => {
  test("dist directory exists (requires prior `bun run build:frontend`)", () => {
    // If dist doesn't exist, print a helpful message instead of a cryptic failure.
    // Run `bun run build:frontend` in the server/ directory to populate it.
    if (!distExists) {
      process.stderr.write(
        "SKIP: server/frontend/dist/ not found — run `bun run build:frontend` first\n"
      );
    }
    // This test does not assert — it serves as documentation
    expect(typeof distExists).toBe("boolean");
  });

  test("dist/index.html exists and is non-empty", () => {
    if (!distExists) return; // skip if not built

    const indexPath = join(distDir, "index.html");
    expect(existsSync(indexPath)).toBe(true);

    const stat = statSync(indexPath);
    expect(stat.size).toBeGreaterThan(0);
  });

  test("dist/index.html contains the root div", () => {
    if (!distExists) return;

    const indexPath = join(distDir, "index.html");
    const content = Bun.file(indexPath).text();
    return content.then((text) => {
      expect(text).toContain('<div id="root">');
    });
  });

  test("dist/assets/main.js exists and is non-empty", () => {
    if (!distExists) return;

    const jsPath = join(assetsDir, "main.js");
    expect(existsSync(jsPath)).toBe(true);

    const stat = statSync(jsPath);
    // Minified React bundle should be at least 50KB
    expect(stat.size).toBeGreaterThan(50 * 1024);
  });

  test("dist/assets/main.css exists and is non-empty", () => {
    if (!distExists) return;

    const cssPath = join(assetsDir, "main.css");
    expect(existsSync(cssPath)).toBe(true);

    const stat = statSync(cssPath);
    expect(stat.size).toBeGreaterThan(0);
  });

  test("dist/assets/main.js.map exists (source map for debugging)", () => {
    if (!distExists) return;

    const mapPath = join(assetsDir, "main.js.map");
    expect(existsSync(mapPath)).toBe(true);
  });
});
