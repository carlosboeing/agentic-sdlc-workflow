/**
 * Tests for SPA static file serving in the Bun server.
 *
 * These tests verify that:
 * 1. The server correctly serves the built SPA files
 * 2. SPA fallback routing works (all non-API paths return index.html)
 * 3. Static assets are served with correct content types
 *
 * The tests use a mock dist directory to avoid requiring a full frontend build.
 */

import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createAppWithStatic, startServer } from "../../src/server";

describe("SPA static file serving", () => {
  let distDir: string;
  let cleanup: () => void;

  beforeAll(() => {
    // Create a temporary dist directory with mock SPA files
    distDir = join(tmpdir(), `spa-test-${Date.now()}`);
    mkdirSync(join(distDir, "assets"), { recursive: true });

    // Create mock index.html
    writeFileSync(
      join(distDir, "index.html"),
      `<!DOCTYPE html>
<html>
<head><title>Workflow Dashboard</title></head>
<body><div id="root"></div></body>
</html>`
    );

    // Create mock JS asset
    writeFileSync(
      join(distDir, "assets", "main.js"),
      `console.log("workflow dashboard");`
    );

    // Create mock CSS asset
    writeFileSync(
      join(distDir, "assets", "main.css"),
      `body { margin: 0; }`
    );

    cleanup = () => rmSync(distDir, { recursive: true, force: true });
  });

  afterAll(() => cleanup?.());

  test("serves index.html at root path /", async () => {
    const app = createAppWithStatic({ distDir });
    const res = await app.fetch(new Request("http://localhost/"));
    expect(res.status).toBe(200);
    const body = await res.text();
    expect(body).toContain("<!DOCTYPE html>");
    expect(body).toContain("Workflow Dashboard");
  });

  test("serves index.html for unknown client-side routes (SPA fallback)", async () => {
    const app = createAppWithStatic({ distDir });

    // These are client-side routes that should all return index.html
    const routes = ["/items/42", "/docs/some-path", "/costs", "/board"];
    for (const route of routes) {
      const res = await app.fetch(new Request(`http://localhost${route}`));
      expect(res.status).toBe(200);
      const body = await res.text();
      expect(body).toContain("<!DOCTYPE html>");
    }
  });

  test("serves static JS assets with correct content type", async () => {
    const app = createAppWithStatic({ distDir });
    const res = await app.fetch(
      new Request("http://localhost/assets/main.js")
    );
    expect(res.status).toBe(200);
    const contentType = res.headers.get("content-type") ?? "";
    expect(contentType).toContain("javascript");
  });

  test("serves static CSS assets with correct content type", async () => {
    const app = createAppWithStatic({ distDir });
    const res = await app.fetch(
      new Request("http://localhost/assets/main.css")
    );
    expect(res.status).toBe(200);
    const contentType = res.headers.get("content-type") ?? "";
    expect(contentType).toContain("css");
  });

  test("API routes are NOT overridden by SPA serving", async () => {
    const app = createAppWithStatic({ distDir });
    // /api/health is a real API route — should not return index.html
    const res = await app.fetch(new Request("http://localhost/api/health"));
    expect(res.status).toBe(200);
    const body = (await res.json()) as { status: string };
    expect(body.status).toBe("ok");
  });

  test("returns 404 for missing static assets (not SPA fallback)", async () => {
    const app = createAppWithStatic({ distDir });
    // Requests for files with extensions should not fall back to index.html
    const res = await app.fetch(
      new Request("http://localhost/assets/missing.js")
    );
    expect(res.status).toBe(404);
  });

  test("index.html response includes no-cache headers for fresh SPA loads", async () => {
    const app = createAppWithStatic({ distDir });
    const res = await app.fetch(new Request("http://localhost/"));
    const cacheControl = res.headers.get("cache-control") ?? "";
    // index.html should not be cached aggressively so deploys take effect
    expect(cacheControl).toContain("no-cache");
  });
});

// ---------------------------------------------------------------------------
// Startup wiring: startServer() must use createAppWithStatic
// ---------------------------------------------------------------------------

describe("startServer production wiring", () => {
  let distDir: string;
  let cleanup: () => void;

  beforeAll(() => {
    distDir = join(tmpdir(), `spa-wiring-test-${Date.now()}`);
    mkdirSync(join(distDir, "assets"), { recursive: true });
    writeFileSync(
      join(distDir, "index.html"),
      `<!DOCTYPE html><html><body><div id="root"></div></body></html>`
    );
    writeFileSync(
      join(distDir, "assets", "main.js"),
      `console.log("wiring test");`
    );
    cleanup = () => rmSync(distDir, { recursive: true, force: true });
  });

  afterAll(() => cleanup?.());

  test("startServer serves the SPA index.html at the root path", async () => {
    // startServer() must use createAppWithStatic() so the production startup
    // path actually serves the React SPA (C1 fix verification).
    const server = startServer({ port: 0, distDir });
    try {
      const res = await fetch(`http://127.0.0.1:${server.port}/`);
      expect(res.status).toBe(200);
      const body = await res.text();
      expect(body).toContain("<!DOCTYPE html>");
    } finally {
      server.stop(true);
    }
  });

  test("startServer serves static assets from distDir", async () => {
    const server = startServer({ port: 0, distDir });
    try {
      const res = await fetch(`http://127.0.0.1:${server.port}/assets/main.js`);
      expect(res.status).toBe(200);
      const contentType = res.headers.get("content-type") ?? "";
      expect(contentType).toContain("javascript");
    } finally {
      server.stop(true);
    }
  });

  test("startServer still serves the API health endpoint", async () => {
    const server = startServer({ port: 0, distDir });
    try {
      const res = await fetch(`http://127.0.0.1:${server.port}/api/health`);
      expect(res.status).toBe(200);
      const body = (await res.json()) as { status: string };
      expect(body.status).toBe("ok");
    } finally {
      server.stop(true);
    }
  });
});
