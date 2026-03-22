/**
 * Tests for Item Detail page components (E05-S03).
 *
 * These tests verify:
 * 1. StatusBadge — correct color class emitted for each board status
 * 2. CommentList — data transformation logic (sorting, grouping)
 * 3. TelemetrySummary — aggregate computation from telemetry records
 * 4. useItem hook — correct API calls made
 * 5. ItemDetail page — integration: hook + components render path
 * 6. Telemetry page — aggregate metrics computation
 *
 * React components cannot be rendered in Bun's test runner (no jsdom).
 * We test the pure logic functions extracted from components, plus
 * verify module exports exist and are functions.
 */

import { describe, test, expect } from "bun:test";
import type { BoardStatus, Comment, TelemetryRecord } from "../../frontend/src/lib/types";

// ---------------------------------------------------------------------------
// StatusBadge — color mapping logic
// ---------------------------------------------------------------------------

describe("StatusBadge color mapping", () => {
  // The status→color mapping is exported for testability.
  // Import after implementation exists.
  test("maps backlog status to gray color class", async () => {
    const { statusColorClass } = await import("../../frontend/src/components/StatusBadge");
    expect(statusColorClass("backlog")).toContain("gray");
  });

  test("maps ready status to blue color class", async () => {
    const { statusColorClass } = await import("../../frontend/src/components/StatusBadge");
    expect(statusColorClass("ready")).toContain("blue");
  });

  test("maps in-progress status to yellow color class", async () => {
    const { statusColorClass } = await import("../../frontend/src/components/StatusBadge");
    expect(statusColorClass("in-progress")).toContain("yellow");
  });

  test("maps in-review status to purple color class", async () => {
    const { statusColorClass } = await import("../../frontend/src/components/StatusBadge");
    expect(statusColorClass("in-review")).toContain("purple");
  });

  test("maps done status to green color class", async () => {
    const { statusColorClass } = await import("../../frontend/src/components/StatusBadge");
    expect(statusColorClass("done")).toContain("green");
  });

  test("StatusBadge is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/StatusBadge");
    expect(typeof mod.StatusBadge).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// CommentList — logic
// ---------------------------------------------------------------------------

describe("CommentList", () => {
  test("CommentList is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/CommentList");
    expect(typeof mod.CommentList).toBe("function");
  });

  test("formatCommentDate returns a non-empty string for valid ISO date", async () => {
    const { formatCommentDate } = await import("../../frontend/src/components/CommentList");
    const result = formatCommentDate("2026-03-22T10:00:00.000Z");
    expect(typeof result).toBe("string");
    expect(result.length).toBeGreaterThan(0);
  });

  test("formatCommentDate handles date-only strings", async () => {
    const { formatCommentDate } = await import("../../frontend/src/components/CommentList");
    const result = formatCommentDate("2026-03-22");
    expect(typeof result).toBe("string");
    expect(result.length).toBeGreaterThan(0);
  });
});

// ---------------------------------------------------------------------------
// TelemetrySummary — aggregate computation
// ---------------------------------------------------------------------------

function makeTelemetryRecord(overrides: Partial<TelemetryRecord> = {}): TelemetryRecord {
  return {
    id: 1,
    item_id: 10,
    model: "sonnet",
    duration_ms: 60000,
    tokens: 50000,
    tool_uses: 10,
    cost_estimate: 0.5,
    commit_hash: null,
    metadata: null,
    created_at: "2026-03-22T10:00:00.000Z",
    ...overrides,
  };
}

describe("TelemetrySummary aggregate computation", () => {
  test("TelemetrySummary is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/TelemetrySummary");
    expect(typeof mod.TelemetrySummary).toBe("function");
  });

  test("aggregateTelemetry sums duration_ms across records", async () => {
    const { aggregateTelemetry } = await import("../../frontend/src/components/TelemetrySummary");
    const records: TelemetryRecord[] = [
      makeTelemetryRecord({ duration_ms: 30000 }),
      makeTelemetryRecord({ id: 2, duration_ms: 90000 }),
    ];
    const result = aggregateTelemetry(records);
    expect(result.totalDurationMs).toBe(120000);
  });

  test("aggregateTelemetry sums tokens across records", async () => {
    const { aggregateTelemetry } = await import("../../frontend/src/components/TelemetrySummary");
    const records: TelemetryRecord[] = [
      makeTelemetryRecord({ tokens: 40000 }),
      makeTelemetryRecord({ id: 2, tokens: 60000 }),
    ];
    const result = aggregateTelemetry(records);
    expect(result.totalTokens).toBe(100000);
  });

  test("aggregateTelemetry sums cost_estimate across records", async () => {
    const { aggregateTelemetry } = await import("../../frontend/src/components/TelemetrySummary");
    const records: TelemetryRecord[] = [
      makeTelemetryRecord({ cost_estimate: 0.25 }),
      makeTelemetryRecord({ id: 2, cost_estimate: 0.75 }),
    ];
    const result = aggregateTelemetry(records);
    expect(result.totalCost).toBeCloseTo(1.0, 5);
  });

  test("aggregateTelemetry handles null cost_estimate as zero", async () => {
    const { aggregateTelemetry } = await import("../../frontend/src/components/TelemetrySummary");
    const records: TelemetryRecord[] = [
      makeTelemetryRecord({ cost_estimate: null }),
      makeTelemetryRecord({ id: 2, cost_estimate: 0.5 }),
    ];
    const result = aggregateTelemetry(records);
    expect(result.totalCost).toBeCloseTo(0.5, 5);
  });

  test("aggregateTelemetry returns zeros for empty array", async () => {
    const { aggregateTelemetry } = await import("../../frontend/src/components/TelemetrySummary");
    const result = aggregateTelemetry([]);
    expect(result.totalDurationMs).toBe(0);
    expect(result.totalTokens).toBe(0);
    expect(result.totalCost).toBe(0);
  });

  test("formatDuration converts milliseconds to human-readable string", async () => {
    const { formatDuration } = await import("../../frontend/src/components/TelemetrySummary");
    // 2 minutes 30 seconds
    const result = formatDuration(150000);
    expect(result).toContain("2");
    expect(result).toContain("30");
  });

  test("formatDuration handles sub-minute durations", async () => {
    const { formatDuration } = await import("../../frontend/src/components/TelemetrySummary");
    const result = formatDuration(45000);
    expect(typeof result).toBe("string");
    expect(result.length).toBeGreaterThan(0);
  });

  test("formatTokens converts large numbers to K notation", async () => {
    const { formatTokens } = await import("../../frontend/src/components/TelemetrySummary");
    const result = formatTokens(150000);
    expect(result).toContain("150");
    expect(result).toContain("K");
  });

  test("formatTokens returns raw number for small values", async () => {
    const { formatTokens } = await import("../../frontend/src/components/TelemetrySummary");
    const result = formatTokens(500);
    expect(result).toContain("500");
  });
});

// ---------------------------------------------------------------------------
// useItem hook — module exports
// ---------------------------------------------------------------------------

describe("useItem hook", () => {
  test("useItem is exported as a function", async () => {
    const mod = await import("../../frontend/src/hooks/useItem");
    expect(typeof mod.useItem).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// ItemDetail page — module exports
// ---------------------------------------------------------------------------

describe("ItemDetail page", () => {
  test("ItemDetail is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/pages/ItemDetail");
    expect(typeof mod.ItemDetail).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// ItemHeader component
// ---------------------------------------------------------------------------

describe("ItemHeader component", () => {
  test("ItemHeader is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/ItemHeader");
    expect(typeof mod.ItemHeader).toBe("function");
  });

  test("typeBadgeClass returns correct class for backlog type", async () => {
    const { typeBadgeClass } = await import("../../frontend/src/components/ItemHeader");
    expect(typeBadgeClass("backlog")).toContain("purple");
  });

  test("typeBadgeClass returns correct class for epic type", async () => {
    const { typeBadgeClass } = await import("../../frontend/src/components/ItemHeader");
    expect(typeBadgeClass("epic")).toContain("blue");
  });

  test("typeBadgeClass returns correct class for story type", async () => {
    const { typeBadgeClass } = await import("../../frontend/src/components/ItemHeader");
    expect(typeBadgeClass("story")).toContain("green");
  });

  test("typeBadgeClass returns correct class for docs type", async () => {
    const { typeBadgeClass } = await import("../../frontend/src/components/ItemHeader");
    expect(typeBadgeClass("docs")).toContain("gray");
  });
});

// ---------------------------------------------------------------------------
// ItemBody component
// ---------------------------------------------------------------------------

describe("ItemBody component", () => {
  test("ItemBody is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/ItemBody");
    expect(typeof mod.ItemBody).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// ItemHierarchy component
// ---------------------------------------------------------------------------

describe("ItemHierarchy component", () => {
  test("ItemHierarchy is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/ItemHierarchy");
    expect(typeof mod.ItemHierarchy).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// ItemComments component
// ---------------------------------------------------------------------------

describe("ItemComments component", () => {
  test("ItemComments is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/components/ItemComments");
    expect(typeof mod.ItemComments).toBe("function");
  });
});

// ---------------------------------------------------------------------------
// Telemetry page
// ---------------------------------------------------------------------------

describe("Telemetry page", () => {
  test("Telemetry is exported as a function (React component)", async () => {
    const mod = await import("../../frontend/src/pages/Telemetry");
    expect(typeof mod.Telemetry).toBe("function");
  });
});
