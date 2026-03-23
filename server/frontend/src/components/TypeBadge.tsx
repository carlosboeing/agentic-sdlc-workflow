/**
 * Color-coded type badge for work items.
 *
 * Colors follow the design doc convention:
 *   backlog = purple, epic = blue, story = green, docs = gray
 */

import type { ItemType } from "../lib/types";
import { getTypeBadgeColor } from "../lib/kanban-utils";

interface TypeBadgeProps {
  type: ItemType;
}

export function TypeBadge({ type }: TypeBadgeProps) {
  const colorClasses = getTypeBadgeColor(type);

  return (
    <span
      className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${colorClasses}`}
    >
      {type}
    </span>
  );
}
