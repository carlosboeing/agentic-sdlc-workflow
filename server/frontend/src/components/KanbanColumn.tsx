/**
 * Kanban column — a single status column containing draggable cards.
 *
 * Acts as a droppable container for dnd-kit. Renders a header with
 * column name + item count, and a scrollable card list. Shows a
 * placeholder message when empty.
 */

import { useDroppable } from "@dnd-kit/core";
import {
  SortableContext,
  verticalListSortingStrategy,
} from "@dnd-kit/sortable";
import type { WorkItem, BoardStatus } from "../lib/types";
import { COLUMN_DISPLAY_NAMES, COLUMN_COLORS } from "../lib/kanban-utils";
import { KanbanCard } from "./KanbanCard";

interface KanbanColumnProps {
  status: BoardStatus;
  items: WorkItem[];
}

export function KanbanColumn({ status, items }: KanbanColumnProps) {
  const { setNodeRef, isOver } = useDroppable({
    id: `column-${status}`,
    data: { status },
  });

  const sortableIds = items.map((item) => `item-${item.id}`);

  return (
    <div
      className="flex flex-col min-w-[240px] max-w-[300px] w-full bg-gray-50 rounded-lg"
      data-testid={`kanban-column-${status}`}
    >
      {/* Column header */}
      <div className="flex items-center gap-2 px-3 py-2.5 border-b border-gray-200">
        <span
          className={`w-2.5 h-2.5 rounded-full ${COLUMN_COLORS[status]}`}
          aria-hidden="true"
        />
        <h3 className="text-sm font-semibold text-gray-700">
          {COLUMN_DISPLAY_NAMES[status]}
        </h3>
        <span className="ml-auto text-xs text-gray-400 font-medium bg-gray-200 rounded-full px-2 py-0.5">
          {items.length}
        </span>
      </div>

      {/* Card list (droppable + sortable) */}
      <div
        ref={setNodeRef}
        className={[
          "flex-1 p-2 space-y-2 overflow-y-auto min-h-[120px]",
          isOver ? "bg-blue-50 ring-1 ring-blue-200 rounded-b-lg" : "",
        ].join(" ")}
      >
        <SortableContext
          items={sortableIds}
          strategy={verticalListSortingStrategy}
        >
          {items.length === 0 ? (
            <div className="flex items-center justify-center h-20 text-xs text-gray-400 italic">
              No items
            </div>
          ) : (
            items.map((item) => (
              <KanbanCard key={item.id} item={item} />
            ))
          )}
        </SortableContext>
      </div>
    </div>
  );
}
