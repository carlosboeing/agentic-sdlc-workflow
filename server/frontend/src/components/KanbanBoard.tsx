/**
 * Kanban board — five-column drag-and-drop board for work items.
 *
 * Columns: Backlog, Ready, In Progress, In Review, Done.
 * Uses @dnd-kit/core for drag-and-drop between columns.
 * Accepts data/callbacks as props (from Dashboard) or fetches via useItems.
 */

import { useState, useCallback } from "react";
import {
  DndContext,
  DragOverlay,
  closestCorners,
  PointerSensor,
  KeyboardSensor,
  useSensor,
  useSensors,
  type DragStartEvent,
  type DragEndEvent,
  type DragOverEvent,
} from "@dnd-kit/core";
import { sortableKeyboardCoordinates } from "@dnd-kit/sortable";
import type { WorkItem, BoardStatus } from "../lib/types";
import { KANBAN_COLUMNS, type GroupedItems } from "../lib/kanban-utils";
import { useItems } from "../hooks/useItems";
import { KanbanColumn } from "./KanbanColumn";
import { KanbanCard } from "./KanbanCard";

export interface KanbanBoardProps {
  /** Pre-fetched grouped items. When provided, the board does not call useItems. */
  grouped?: GroupedItems;
  loading?: boolean;
  error?: string | null;
  moveItem?: (itemId: number, newStatus: BoardStatus) => Promise<void>;
}

export function KanbanBoard(props: KanbanBoardProps = {}) {
  // Use data from props when provided (e.g., when Dashboard owns the state).
  // Fall back to internal useItems when rendered standalone (e.g., in tests).
  const internal = useItems();
  const grouped = props.grouped ?? internal.grouped;
  const loading = props.loading !== undefined ? props.loading : internal.loading;
  const error = props.error !== undefined ? props.error : internal.error;
  const moveItem = props.moveItem ?? internal.moveItem;

  const [activeItem, setActiveItem] = useState<WorkItem | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, {
      activationConstraint: {
        // Require 5px movement before drag starts (so clicks still work)
        distance: 5,
      },
    }),
    useSensor(KeyboardSensor, {
      coordinateGetter: sortableKeyboardCoordinates,
    })
  );

  const handleDragStart = useCallback(
    (event: DragStartEvent) => {
      const { active } = event;
      const item = active.data.current?.item as WorkItem | undefined;
      if (item) {
        setActiveItem(item);
      }
    },
    []
  );

  const handleDragEnd = useCallback(
    (event: DragEndEvent) => {
      const { active, over } = event;
      setActiveItem(null);

      if (!over) return;

      // Determine the target column status
      let targetStatus: BoardStatus | null = null;

      // Dropped on a column
      if (typeof over.id === "string" && over.id.startsWith("column-")) {
        targetStatus = over.id.replace("column-", "") as BoardStatus;
      }
      // Dropped on another item — use that item's column
      else if (over.data.current?.item) {
        targetStatus = (over.data.current.item as WorkItem).status;
      }
      // Dropped on a sortable item's container
      else if (over.data.current?.sortable) {
        const containerId = over.data.current.sortable.containerId as string;
        if (containerId.startsWith("column-")) {
          targetStatus = containerId.replace("column-", "") as BoardStatus;
        }
      }

      if (!targetStatus) return;

      // Extract the item ID from the active draggable
      const activeIdStr = String(active.id);
      const itemId = parseInt(activeIdStr.replace("item-", ""), 10);
      if (isNaN(itemId)) return;

      // Find the item to check if status actually changed
      const item = active.data.current?.item as WorkItem | undefined;
      if (item && item.status === targetStatus) return;

      // Fire the optimistic update
      moveItem(itemId, targetStatus);
    },
    [moveItem]
  );

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-gray-400 text-sm">Loading board...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="text-red-500 text-sm">
          Error loading board: {error}
        </div>
      </div>
    );
  }

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div
        className="flex gap-3 p-4 overflow-x-auto h-full"
        data-testid="kanban-board"
      >
        {KANBAN_COLUMNS.map((status) => (
          <KanbanColumn
            key={status}
            status={status}
            items={grouped[status]}
          />
        ))}
      </div>

      {/* Drag overlay — shows a ghost of the card being dragged */}
      <DragOverlay>
        {activeItem ? (
          <div className="opacity-80 rotate-2 scale-105">
            <KanbanCard item={activeItem} />
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
  );
}
