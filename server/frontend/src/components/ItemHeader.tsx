/**
 * ItemHeader — displays title, type badge, status badge, and labels
 * for a work item.
 *
 * Exports `typeBadgeClass` as a pure function for testability.
 */

import type { WorkItem } from "../lib/types";
import type { ItemType } from "../lib/types";
import { StatusBadge } from "./StatusBadge";

// ---------------------------------------------------------------------------
// Pure helpers — exported for tests
// ---------------------------------------------------------------------------

/** Returns the Tailwind class string for a given item type. */
export function typeBadgeClass(type: ItemType): string {
  switch (type) {
    case "backlog":
      return "bg-purple-100 text-purple-700";
    case "epic":
      return "bg-blue-100 text-blue-700";
    case "story":
      return "bg-green-100 text-green-700";
    case "docs":
      return "bg-gray-100 text-gray-600";
    default:
      return "bg-gray-100 text-gray-600";
  }
}

/** Human-readable label for an item type. */
function typeLabel(type: ItemType): string {
  switch (type) {
    case "backlog":
      return "Backlog";
    case "epic":
      return "Epic";
    case "story":
      return "Story";
    case "docs":
      return "Docs";
    default:
      return type;
  }
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface ItemHeaderProps {
  item: WorkItem;
  /** Optional back link URL (e.g. parent path). */
  backHref?: string;
}

export function ItemHeader({ item, backHref }: ItemHeaderProps) {
  const labelColors = [
    "bg-indigo-100 text-indigo-700",
    "bg-pink-100 text-pink-700",
    "bg-amber-100 text-amber-700",
    "bg-teal-100 text-teal-700",
    "bg-rose-100 text-rose-700",
  ];

  function labelColorForIndex(i: number): string {
    return labelColors[i % labelColors.length];
  }

  return (
    <div>
      {/* Back link */}
      {backHref && (
        <a
          href={backHref}
          className="inline-flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 mb-3 transition-colors"
        >
          ← Back
        </a>
      )}

      {/* Type + status badges row */}
      <div className="flex flex-wrap items-center gap-2 mb-2">
        <span
          className={[
            "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
            typeBadgeClass(item.type),
          ].join(" ")}
        >
          {typeLabel(item.type)}
        </span>
        <StatusBadge status={item.status} />
        {item.state === "closed" && (
          <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-500 line-through">
            Closed
          </span>
        )}
      </div>

      {/* Title */}
      <h1 className="text-xl font-semibold text-gray-900 leading-snug mb-2">
        {item.title}
      </h1>

      {/* Labels */}
      {item.labels && item.labels.length > 0 && (
        <div className="flex flex-wrap gap-1.5">
          {item.labels.map((label, i) => (
            <span
              key={label.id}
              title={label.description ?? undefined}
              className={[
                "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                labelColorForIndex(i),
              ].join(" ")}
              style={
                label.color
                  ? { backgroundColor: `${label.color}20`, color: label.color }
                  : undefined
              }
            >
              {label.name}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
