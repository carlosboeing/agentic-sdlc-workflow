/**
 * Tests for the frontend HTTP API client wrapper (lib/api.ts).
 *
 * Uses a mock fetch to verify the client constructs correct request URLs,
 * method, headers, and bodies — and surfaces errors correctly.
 */

import { describe, test, expect, beforeEach, mock } from "bun:test";
import { createApiClient, ApiClientError } from "../../frontend/src/lib/api";

// ---------------------------------------------------------------------------
// Mock fetch
// ---------------------------------------------------------------------------

function makeMockFetch(
  status: number,
  body: unknown,
  headers: Record<string, string> = {}
) {
  return mock(async (_url: string | URL | Request, _init?: RequestInit) => {
    return new Response(JSON.stringify(body), {
      status,
      headers: { "content-type": "application/json", ...headers },
    });
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("ApiClient", () => {
  describe("getHealth", () => {
    test("calls GET /api/health", async () => {
      const fetchMock = makeMockFetch(200, { status: "ok", uptime: 42 });
      const client = createApiClient();
      // Temporarily replace global fetch
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        const result = await client.getHealth();
        expect(result.status).toBe("ok");
        expect(result.uptime).toBe(42);
        expect(fetchMock).toHaveBeenCalledWith("/api/health");
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });

  describe("listItems", () => {
    test("calls GET /api/items without params", async () => {
      const fetchMock = makeMockFetch(200, []);
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        await client.listItems();
        expect(fetchMock).toHaveBeenCalledWith("/api/items");
      } finally {
        globalThis.fetch = originalFetch;
      }
    });

    test("includes query params when provided", async () => {
      const fetchMock = makeMockFetch(200, []);
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        await client.listItems({ type: "story", status: "in-progress" });
        const calledUrl = (fetchMock.mock.calls[0] as unknown[])[0] as string;
        expect(calledUrl).toContain("type=story");
        expect(calledUrl).toContain("status=in-progress");
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });

  describe("createItem", () => {
    test("calls POST /api/items with JSON body", async () => {
      const item = { id: 1, title: "Test Story" };
      const fetchMock = makeMockFetch(201, item);
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        await client.createItem({ type: "story", title: "Test Story" });
        const call = fetchMock.mock.calls[0] as unknown[];
        const init = call[1] as RequestInit;
        expect(init.method).toBe("POST");
        expect(init.headers).toMatchObject({ "Content-Type": "application/json" });
        const body = JSON.parse(init.body as string) as Record<string, unknown>;
        expect(body.title).toBe("Test Story");
        expect(body.type).toBe("story");
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });

  describe("error handling", () => {
    test("throws ApiClientError on non-200 response", async () => {
      const fetchMock = makeMockFetch(404, { error: "Not found" });
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        await expect(client.getItem(999)).rejects.toBeInstanceOf(ApiClientError);
      } finally {
        globalThis.fetch = originalFetch;
      }
    });

    test("ApiClientError includes status code", async () => {
      const fetchMock = makeMockFetch(500, { error: "Internal error" });
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        try {
          await client.getItem(1);
        } catch (err) {
          expect(err).toBeInstanceOf(ApiClientError);
          expect((err as ApiClientError).status).toBe(500);
        }
      } finally {
        globalThis.fetch = originalFetch;
      }
    });

    test("ApiClientError message comes from server error field", async () => {
      const fetchMock = makeMockFetch(422, { error: "Validation failed" });
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        try {
          await client.createItem({ type: "story", title: "" });
        } catch (err) {
          expect(err).toBeInstanceOf(ApiClientError);
          expect((err as ApiClientError).message).toBe("Validation failed");
        }
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });

  describe("base URL support", () => {
    test("prepends custom base URL to requests", async () => {
      const fetchMock = makeMockFetch(200, { status: "ok", uptime: 0 });
      const client = createApiClient("http://localhost:3117");
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        await client.getHealth();
        expect(fetchMock).toHaveBeenCalledWith(
          "http://localhost:3117/api/health"
        );
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });

  describe("204 No Content handling", () => {
    test("del() resolves without throwing when server returns 204 No Content", async () => {
      // DELETE endpoints following REST conventions may return 204 No Content.
      // del() must not attempt to parse JSON on an empty body.
      const fetchMock = mock(async (_url: string | URL | Request, _init?: RequestInit) => {
        return new Response(null, { status: 204 });
      });
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        const result = await client.closeItem(42);
        // 204 with no body → result should be undefined (or null), not thrown
        expect(result).toBeUndefined();
      } finally {
        globalThis.fetch = originalFetch;
      }
    });

    test("post() resolves without throwing when server returns 204 No Content", async () => {
      const fetchMock = mock(async (_url: string | URL | Request, _init?: RequestInit) => {
        return new Response(null, { status: 204 });
      });
      const client = createApiClient();
      const originalFetch = globalThis.fetch;
      globalThis.fetch = fetchMock as unknown as typeof fetch;

      try {
        const result = await client.linkChild(1, 2);
        expect(result).toBeUndefined();
      } finally {
        globalThis.fetch = originalFetch;
      }
    });
  });
});
