/**
 * Pure utility functions for the Kanban board.
 *
 * Extracted from components for testability — no React imports, no DOM.
 * Covers column definitions, item grouping, badge colors, label parsing.
 */

import type { WorkItem, BoardStatus, ItemType, Label } from "./types";

// ---------------------------------------------------------------------------
// Column definitions
// ---------------------------------------------------------------------------

/**
 * The five Kanban columns in display order.
 * Matches the BoardStatus union type from types.ts.
 */
export const KANBAN_COLUMNS: BoardStatus[] = [
  "backlog",
  "ready",
  "in-progress",
  "in-review",
  "done",
];

/**
 * Human-readable display names for each column.
 */
export const COLUMN_DISPLAY_NAMES: Record<BoardStatus, string> = {
  "backlog": "Backlog",
  "ready": "Ready",
  "in-progress": "In Progress",
  "in-review": "In Review",
  "done": "Done",
};

// ---------------------------------------------------------------------------
// Item grouping
// ---------------------------------------------------------------------------

/** Items grouped by board status — every column key is always present. */
export type GroupedItems = Record<BoardStatus, WorkItem[]>;

/**
 * Groups work items by their board status.
 * Returns an object with all five status keys, each mapping to an array
 * of items (possibly empty).
 */
export function groupItemsByStatus(items: WorkItem[]): GroupedItems {
  const grouped: GroupedItems = {
    "backlog": [],
    "ready": [],
    "in-progress": [],
    "in-review": [],
    "done": [],
  };

  for (const item of items) {
    if (grouped[item.status]) {
      grouped[item.status].push(item);
    }
  }

  return grouped;
}

// ---------------------------------------------------------------------------
// Type badge colors
// ---------------------------------------------------------------------------

/**
 * Returns Tailwind CSS classes for the type badge background and text.
 * Color scheme follows the design doc:
 *   backlog = purple, epic = blue, story = green, docs = gray
 */
export function getTypeBadgeColor(type: ItemType): string {
  switch (type) {
    case "backlog":
      return "bg-purple-100 text-purple-700";
    case "epic":
      return "bg-blue-100 text-blue-700";
    case "story":
      return "bg-green-100 text-green-700";
    case "docs":
      return "bg-gray-100 text-gray-700";
    default:
      return "bg-gray-100 text-gray-700";
  }
}

// ---------------------------------------------------------------------------
// Difficulty label parsing
// ---------------------------------------------------------------------------

/**
 * Extracts the difficulty level from an item's labels array.
 * Labels follow the `difficulty/<level>` convention.
 * Returns the level string ("easy", "medium", "hard") or null.
 */
export function getDifficultyLabel(
  labels: Label[] | undefined
): string | null {
  if (!labels || labels.length === 0) return null;

  const diffLabel = labels.find((l) => l.name.startsWith("difficulty/"));
  if (!diffLabel) return null;

  return diffLabel.name.replace("difficulty/", "");
}

// ---------------------------------------------------------------------------
// Column header colors
// ---------------------------------------------------------------------------

/** Column header accent colors for visual differentiation. */
export const COLUMN_COLORS: Record<BoardStatus, string> = {
  "backlog": "bg-gray-200",
  "ready": "bg-blue-200",
  "in-progress": "bg-amber-200",
  "in-review": "bg-purple-200",
  "done": "bg-green-200",
};
