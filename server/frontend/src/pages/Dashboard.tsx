/**
 * Dashboard page — renders the Kanban board overview with real-time updates.
 *
 * Displays work items organized by board status in a five-column
 * drag-and-drop Kanban board. WebSocket events automatically update
 * the board without requiring a manual refresh.
 */

import { useCallback } from "react";
import { KanbanBoard } from "../components/KanbanBoard";
import { useItems } from "../hooks/useItems";
import { useWebSocket } from "../hooks/useWebSocket";
import type { ActivityMessage } from "../hooks/useWebSocket";

export function Dashboard() {
  const { grouped, loading, error, moveItem, applyWsMessage } = useItems();

  // Apply WebSocket events to the Kanban board cache
  const handleMessage = useCallback(
    (msg: ActivityMessage) => {
      applyWsMessage(msg);
    },
    [applyWsMessage]
  );

  useWebSocket({ onMessage: handleMessage });

  return (
    <div className="flex flex-col h-full">
      <div className="shrink-0 px-6 pt-4 pb-2">
        <h1 className="text-lg font-bold text-gray-900">Board</h1>
      </div>
      <div className="flex-1 overflow-hidden">
        <KanbanBoard
          grouped={grouped}
          loading={loading}
          error={error}
          moveItem={moveItem}
        />
      </div>
    </div>
  );
}
