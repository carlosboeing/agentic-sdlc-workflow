/**
 * Dashboard page — renders the Kanban board overview.
 *
 * Displays work items organized by board status in a five-column
 * drag-and-drop Kanban board.
 */

import { KanbanBoard } from "../components/KanbanBoard";

export function Dashboard() {
  return (
    <div className="flex flex-col h-full">
      <div className="shrink-0 px-6 pt-4 pb-2">
        <h1 className="text-lg font-bold text-gray-900">Board</h1>
      </div>
      <div className="flex-1 overflow-hidden">
        <KanbanBoard />
      </div>
    </div>
  );
}
