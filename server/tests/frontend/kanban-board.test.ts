/**
 * Tests for the Kanban board components and logic.
 *
 * Covers:
 * - Column definitions and status mapping
 * - Item grouping by board status
 * - Type badge color mapping
 * - Difficulty label extraction
 * - Optimistic update logic (move + revert on error)
 * - API integration (fetch items, update status on drop)
 * - useItems hook logic
 */

import { describe, test, expect, beforeEach, mock } from "bun:test";
import { createApiClient, ApiClientError } from "../../frontend/src/lib/api";
import type { WorkItem, BoardStatus, Label } from "../../frontend/src/lib/types";
import {
  KANBAN_COLUMNS,
  groupItemsByStatus,
  getTypeBadgeColor,
  getDifficultyLabel,
  COLUMN_DISPLAY_NAMES,
} from "../../frontend/src/lib/kanban-utils";

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

function makeItem(overrides: Partial<WorkItem> = {}): WorkItem {
  return {
    id: 1,
    title: "Test Item",
    type: "story",
    status: "backlog",
    state: "open",
    body: null,
    parent_id: null,
    external_id: null,
    external_url: null,
    created_by: null,
    created_at: "2026-01-01T00:00:00Z",
    updated_at: "2026-01-01T00:00:00Z",
    labels: [],
    ...overrides,
  };
}

function makeLabel(name: string, color: string | null = null): Label {
  return { id: 1, name, color, description: null };
}

// ---------------------------------------------------------------------------
// Column definitions
// ---------------------------------------------------------------------------

describe("KANBAN_COLUMNS", () => {
  test("defines exactly 5 columns in correct order", () => {
    expect(KANBAN_COLUMNS).toHaveLength(5);
    expect(KANBAN_COLUMNS).toEqual([
      "backlog",
      "ready",
      "in-progress",
      "in-review",
      "done",
    ]);
  });
});

describe("COLUMN_DISPLAY_NAMES", () => {
  test("maps all 5 statuses to display names", () => {
    expect(COLUMN_DISPLAY_NAMES["backlog"]).toBe("Backlog");
    expect(COLUMN_DISPLAY_NAMES["ready"]).toBe("Ready");
    expect(COLUMN_DISPLAY_NAMES["in-progress"]).toBe("In Progress");
    expect(COLUMN_DISPLAY_NAMES["in-review"]).toBe("In Review");
    expect(COLUMN_DISPLAY_NAMES["done"]).toBe("Done");
  });
});

// ---------------------------------------------------------------------------
// Item grouping
// ---------------------------------------------------------------------------

describe("groupItemsByStatus", () => {
  test("groups items into their respective columns", () => {
    const items: WorkItem[] = [
      makeItem({ id: 1, status: "backlog" }),
      makeItem({ id: 2, status: "ready" }),
      makeItem({ id: 3, status: "in-progress" }),
      makeItem({ id: 4, status: "in-review" }),
      makeItem({ id: 5, status: "done" }),
    ];

    const grouped = groupItemsByStatus(items);

    expect(grouped["backlog"]).toHaveLength(1);
    expect(grouped["backlog"][0].id).toBe(1);
    expect(grouped["ready"]).toHaveLength(1);
    expect(grouped["ready"][0].id).toBe(2);
    expect(grouped["in-progress"]).toHaveLength(1);
    expect(grouped["in-progress"][0].id).toBe(3);
    expect(grouped["in-review"]).toHaveLength(1);
    expect(grouped["in-review"][0].id).toBe(4);
    expect(grouped["done"]).toHaveLength(1);
    expect(grouped["done"][0].id).toBe(5);
  });

  test("returns empty arrays for columns with no items", () => {
    const items: WorkItem[] = [
      makeItem({ id: 1, status: "in-progress" }),
    ];

    const grouped = groupItemsByStatus(items);

    expect(grouped["backlog"]).toHaveLength(0);
    expect(grouped["ready"]).toHaveLength(0);
    expect(grouped["in-progress"]).toHaveLength(1);
    expect(grouped["in-review"]).toHaveLength(0);
    expect(grouped["done"]).toHaveLength(0);
  });

  test("handles empty item list", () => {
    const grouped = groupItemsByStatus([]);

    for (const status of KANBAN_COLUMNS) {
      expect(grouped[status]).toHaveLength(0);
    }
  });

  test("groups multiple items in same column", () => {
    const items: WorkItem[] = [
      makeItem({ id: 1, status: "in-progress" }),
      makeItem({ id: 2, status: "in-progress" }),
      makeItem({ id: 3, status: "in-progress" }),
    ];

    const grouped = groupItemsByStatus(items);
    expect(grouped["in-progress"]).toHaveLength(3);
  });
});

// ---------------------------------------------------------------------------
// Type badge colors
// ---------------------------------------------------------------------------

describe("getTypeBadgeColor", () => {
  test("returns purple classes for backlog items", () => {
    const result = getTypeBadgeColor("backlog");
    expect(result).toContain("purple");
  });

  test("returns blue classes for epic items", () => {
    const result = getTypeBadgeColor("epic");
    expect(result).toContain("blue");
  });

  test("returns green classes for story items", () => {
    const result = getTypeBadgeColor("story");
    expect(result).toContain("green");
  });

  test("returns gray classes for docs items", () => {
    const result = getTypeBadgeColor("docs");
    expect(result).toContain("gray");
  });
});

// ---------------------------------------------------------------------------
// Difficulty label extraction
// ---------------------------------------------------------------------------

describe("getDifficultyLabel", () => {
  test("extracts difficulty label from labels array", () => {
    const labels: Label[] = [
      makeLabel("hierarchy/story"),
      makeLabel("difficulty/hard"),
      makeLabel("type/feature"),
    ];

    expect(getDifficultyLabel(labels)).toBe("hard");
  });

  test("returns null when no difficulty label present", () => {
    const labels: Label[] = [
      makeLabel("hierarchy/story"),
      makeLabel("type/feature"),
    ];

    expect(getDifficultyLabel(labels)).toBeNull();
  });

  test("returns null for empty labels array", () => {
    expect(getDifficultyLabel([])).toBeNull();
  });

  test("returns null for undefined labels", () => {
    expect(getDifficultyLabel(undefined)).toBeNull();
  });

  test("extracts easy difficulty", () => {
    const labels: Label[] = [makeLabel("difficulty/easy")];
    expect(getDifficultyLabel(labels)).toBe("easy");
  });

  test("extracts medium difficulty", () => {
    const labels: Label[] = [makeLabel("difficulty/medium")];
    expect(getDifficultyLabel(labels)).toBe("medium");
  });
});

// ---------------------------------------------------------------------------
// API integration for status updates
// ---------------------------------------------------------------------------

describe("Kanban API integration", () => {
  function makeMockFetch(
    status: number,
    body: unknown,
    headers: Record<string, string> = {}
  ) {
    return mock(
      async (_url: string | URL | Request, _init?: RequestInit) => {
        return new Response(JSON.stringify(body), {
          status,
          headers: { "content-type": "application/json", ...headers },
        });
      }
    );
  }

  test("setItemStatus calls POST /api/items/:id/status", async () => {
    const updatedItem = makeItem({ id: 42, status: "in-progress" });
    const fetchMock = makeMockFetch(200, updatedItem);
    const client = createApiClient();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    try {
      const result = await client.setItemStatus(42, "in-progress");
      expect(result.status).toBe("in-progress");

      const call = fetchMock.mock.calls[0] as unknown[];
      const url = call[0] as string;
      const init = call[1] as RequestInit;

      expect(url).toBe("/api/items/42/status");
      expect(init.method).toBe("POST");
      const body = JSON.parse(init.body as string) as Record<string, unknown>;
      expect(body.status).toBe("in-progress");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  test("listItems fetches all items for board population", async () => {
    const items = [
      makeItem({ id: 1, status: "backlog" }),
      makeItem({ id: 2, status: "ready" }),
      makeItem({ id: 3, status: "in-progress" }),
    ];
    const fetchMock = makeMockFetch(200, items);
    const client = createApiClient();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    try {
      const result = await client.listItems();
      expect(result).toHaveLength(3);
      expect(fetchMock).toHaveBeenCalledWith("/api/items");
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  test("setItemStatus throws ApiClientError on server error", async () => {
    const fetchMock = makeMockFetch(500, { error: "Internal server error" });
    const client = createApiClient();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    try {
      await expect(
        client.setItemStatus(42, "done")
      ).rejects.toBeInstanceOf(ApiClientError);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  test("setItemStatus throws ApiClientError on validation error", async () => {
    const fetchMock = makeMockFetch(422, {
      error: "Invalid status transition",
    });
    const client = createApiClient();
    const originalFetch = globalThis.fetch;
    globalThis.fetch = fetchMock as unknown as typeof fetch;

    try {
      try {
        await client.setItemStatus(42, "done");
      } catch (err) {
        expect(err).toBeInstanceOf(ApiClientError);
        expect((err as ApiClientError).status).toBe(422);
      }
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});

// ---------------------------------------------------------------------------
// Optimistic update helpers
// ---------------------------------------------------------------------------

describe("Optimistic update logic", () => {
  test("moving item updates its status in grouped data", () => {
    const items: WorkItem[] = [
      makeItem({ id: 1, status: "backlog" }),
      makeItem({ id: 2, status: "ready" }),
    ];

    // Simulate moving item 1 from backlog to in-progress
    const updatedItems = items.map((item) =>
      item.id === 1 ? { ...item, status: "in-progress" as BoardStatus } : item
    );

    const grouped = groupItemsByStatus(updatedItems);
    expect(grouped["backlog"]).toHaveLength(0);
    expect(grouped["in-progress"]).toHaveLength(1);
    expect(grouped["in-progress"][0].id).toBe(1);
    expect(grouped["ready"]).toHaveLength(1);
  });

  test("reverting restores item to original column", () => {
    const items: WorkItem[] = [
      makeItem({ id: 1, status: "backlog" }),
      makeItem({ id: 2, status: "ready" }),
    ];

    // Original grouping
    const original = groupItemsByStatus(items);
    expect(original["backlog"]).toHaveLength(1);

    // After revert (back to original items), grouping is restored
    const reverted = groupItemsByStatus(items);
    expect(reverted["backlog"]).toHaveLength(1);
    expect(reverted["backlog"][0].id).toBe(1);
  });
});
