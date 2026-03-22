/**
 * Kanban card — displays a single work item within a column.
 *
 * Shows: item number, title, type badge (color-coded), difficulty label.
 * Clickable — navigates to the item detail page.
 * Draggable via dnd-kit's useSortable hook.
 */

import { useSortable } from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { useNavigate } from "react-router-dom";
import type { WorkItem } from "../lib/types";
import { getDifficultyLabel } from "../lib/kanban-utils";
import { TypeBadge } from "./TypeBadge";

interface KanbanCardProps {
  item: WorkItem;
}

const DIFFICULTY_COLORS: Record<string, string> = {
  easy: "bg-green-50 text-green-600 border-green-200",
  medium: "bg-amber-50 text-amber-600 border-amber-200",
  hard: "bg-red-50 text-red-600 border-red-200",
};

export function KanbanCard({ item }: KanbanCardProps) {
  const navigate = useNavigate();
  const difficulty = getDifficultyLabel(item.labels);

  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({
    id: `item-${item.id}`,
    data: { item },
  });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  function handleClick(e: React.MouseEvent) {
    // Only navigate if not dragging
    if (!isDragging) {
      navigate(`/items/${item.id}`);
    }
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter" || e.key === " ") {
      e.preventDefault();
      navigate(`/items/${item.id}`);
    }
  }

  return (
    <div
      ref={setNodeRef}
      style={style}
      {...attributes}
      {...listeners}
      onClick={handleClick}
      onKeyDown={handleKeyDown}
      role="button"
      tabIndex={0}
      className={[
        "bg-white rounded-lg border border-gray-200 p-3 shadow-sm",
        "hover:shadow-md hover:border-gray-300 transition-shadow",
        "cursor-grab active:cursor-grabbing",
        isDragging ? "ring-2 ring-blue-400 ring-opacity-50" : "",
      ].join(" ")}
      data-testid={`kanban-card-${item.id}`}
    >
      {/* Item number */}
      <div className="text-xs text-gray-400 font-mono mb-1">
        #{item.id}
      </div>

      {/* Title */}
      <div className="text-sm font-medium text-gray-900 mb-2 line-clamp-2">
        {item.title}
      </div>

      {/* Footer: type badge + difficulty */}
      <div className="flex items-center gap-1.5 flex-wrap">
        <TypeBadge type={item.type} />

        {difficulty && (
          <span
            className={[
              "inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium border",
              DIFFICULTY_COLORS[difficulty] ?? "bg-gray-50 text-gray-500 border-gray-200",
            ].join(" ")}
          >
            {difficulty}
          </span>
        )}
      </div>
    </div>
  );
}
