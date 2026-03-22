import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { Hono } from "hono";
import { createHealthRouter } from "../../src/server";

describe("GET /api/health", () => {
  let app: Hono;
  let startTime: number;

  beforeEach(() => {
    startTime = Date.now() - 5000; // Pretend server started 5 seconds ago
    app = new Hono();
    app.route("/api", createHealthRouter(startTime));
  });

  test("returns 200 status", async () => {
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    expect(res.status).toBe(200);
  });

  test("returns JSON content type", async () => {
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    expect(res.headers.get("content-type")).toContain("application/json");
  });

  test("returns status ok", async () => {
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    const body = (await res.json()) as { status: string; uptime: number };
    expect(body.status).toBe("ok");
  });

  test("returns uptime in seconds", async () => {
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    const body = (await res.json()) as { status: string; uptime: number };
    expect(typeof body.uptime).toBe("number");
    // Uptime should be approximately 5 seconds (we set start 5s ago)
    expect(body.uptime).toBeGreaterThanOrEqual(4);
    expect(body.uptime).toBeLessThan(60);
  });

  test("returns integer uptime (truncated seconds)", async () => {
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    const body = (await res.json()) as { status: string; uptime: number };
    // Uptime should be an integer number of seconds
    expect(Number.isInteger(body.uptime)).toBe(true);
  });

  test("uptime increases over time", async () => {
    // Use a start time 10 seconds in the past
    const tenSecondsAgo = Date.now() - 10000;
    const testApp = new Hono();
    testApp.route("/api", createHealthRouter(tenSecondsAgo));

    const req = new Request("http://localhost/api/health");
    const res = await testApp.fetch(req);
    const body = (await res.json()) as { status: string; uptime: number };
    expect(body.uptime).toBeGreaterThanOrEqual(9);
  });

  test("returns correct format: { status, uptime }", async () => {
    const req = new Request("http://localhost/api/health");
    const res = await app.fetch(req);
    const body = (await res.json()) as Record<string, unknown>;
    expect(Object.keys(body).sort()).toEqual(["status", "uptime"].sort());
  });
});
