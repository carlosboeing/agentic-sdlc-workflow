/**
 * Item Detail page — single work item view.
 *
 * Placeholder for E05-S03 (Item Detail and Telemetry Summary).
 * Will show item metadata, comments, telemetry history, and child items.
 */

import { useParams } from "react-router-dom";

export function ItemDetail() {
  const { id } = useParams<{ id: string }>();

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">
        Item Detail {id ? `#${id}` : ""}
      </h1>
      <p className="text-gray-500">
        Item detail view — coming in E05-S03. This page will show the full
        work item with metadata, comments, telemetry history, and child items.
      </p>
    </div>
  );
}
