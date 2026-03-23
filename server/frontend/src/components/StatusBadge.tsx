/**
 * StatusBadge — colored badge for board status values.
 *
 * Exports both the React component and the `statusColorClass` pure function
 * so the color mapping can be unit-tested without a DOM.
 */

import type { BoardStatus } from "../lib/types";

// ---------------------------------------------------------------------------
// Color mapping — exported for tests
// ---------------------------------------------------------------------------

/** Returns the Tailwind class string for a given board status. */
export function statusColorClass(status: BoardStatus): string {
  switch (status) {
    case "backlog":
      return "bg-gray-100 text-gray-700 ring-gray-200";
    case "ready":
      return "bg-blue-100 text-blue-700 ring-blue-200";
    case "in-progress":
      return "bg-yellow-100 text-yellow-700 ring-yellow-200";
    case "in-review":
      return "bg-purple-100 text-purple-700 ring-purple-200";
    case "done":
      return "bg-green-100 text-green-700 ring-green-200";
    default:
      return "bg-gray-100 text-gray-600 ring-gray-200";
  }
}

/** Human-readable label for a board status. */
export function statusLabel(status: BoardStatus): string {
  switch (status) {
    case "backlog":
      return "Backlog";
    case "ready":
      return "Ready";
    case "in-progress":
      return "In Progress";
    case "in-review":
      return "In Review";
    case "done":
      return "Done";
    default:
      return status;
  }
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface StatusBadgeProps {
  status: BoardStatus;
  className?: string;
}

export function StatusBadge({ status, className = "" }: StatusBadgeProps) {
  const colorClasses = statusColorClass(status);

  return (
    <span
      className={[
        "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ring-1 ring-inset",
        colorClasses,
        className,
      ]
        .filter(Boolean)
        .join(" ")}
    >
      {statusLabel(status)}
    </span>
  );
}
