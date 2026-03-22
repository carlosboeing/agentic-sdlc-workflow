/**
 * useItems hook — fetches work items and provides optimistic status updates.
 *
 * Handles:
 * - Initial data fetch from GET /api/items
 * - Optimistic UI: updates local state immediately on drag-and-drop
 * - Reverts on API error
 * - Refetch after successful status change
 * - WebSocket cache updates: apply status:changed events without a full refetch
 */

import { useState, useEffect, useCallback, useRef } from "react";
import { api } from "../lib/api";
import type { WorkItem, BoardStatus } from "../lib/types";
import { groupItemsByStatus, type GroupedItems } from "../lib/kanban-utils";
import type { ActivityMessage } from "./useWebSocket";

interface UseItemsResult {
  /** Items grouped by board status. */
  grouped: GroupedItems;
  /** Flat list of all items. */
  items: WorkItem[];
  /** Whether the initial load is in progress. */
  loading: boolean;
  /** Error from the last fetch, if any. */
  error: string | null;
  /** Move an item to a new status (optimistic update + API call). */
  moveItem: (itemId: number, newStatus: BoardStatus) => Promise<void>;
  /** Refetch all items from the server. */
  refetch: () => Promise<void>;
  /**
   * Apply a WebSocket message to the local cache.
   * Pass this to useWebSocket's onMessage to keep the board in sync
   * without polling.
   */
  applyWsMessage: (msg: ActivityMessage) => void;
}

export function useItems(): UseItemsResult {
  const [items, setItems] = useState<WorkItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Store previous items for optimistic revert
  const prevItemsRef = useRef<WorkItem[]>([]);

  const fetchItems = useCallback(async () => {
    try {
      const data = await api.listItems();
      setItems(data);
      setError(null);
    } catch (err) {
      const message =
        err instanceof Error ? err.message : "Failed to fetch items";
      setError(message);
    } finally {
      setLoading(false);
    }
  }, []);

  // Initial fetch
  useEffect(() => {
    fetchItems();
  }, [fetchItems]);

  const moveItem = useCallback(
    async (itemId: number, newStatus: BoardStatus) => {
      // Save current state for potential revert
      prevItemsRef.current = items;

      // Optimistic update: move the item in local state immediately
      setItems((prev) =>
        prev.map((item) =>
          item.id === itemId ? { ...item, status: newStatus } : item
        )
      );

      try {
        // Call the API to persist the status change
        await api.setItemStatus(itemId, newStatus);
        // Refetch to get server-confirmed state
        await fetchItems();
      } catch (err) {
        // Revert to previous state on error
        setItems(prevItemsRef.current);
        const message =
          err instanceof Error ? err.message : "Failed to update status";
        setError(message);
      }
    },
    [items, fetchItems]
  );

  /**
   * Apply a WebSocket message to the local cache.
   * - status:changed: update the affected item's status in place (no refetch)
   * - item:created, item:closed: trigger a refetch to get the full item
   */
  const applyWsMessage = useCallback(
    (msg: ActivityMessage) => {
      if (msg.type === "status:changed") {
        const data = msg.data as { itemId?: number; to?: BoardStatus };
        if (data.itemId && data.to) {
          setItems((prev) =>
            prev.map((item) =>
              item.id === data.itemId ? { ...item, status: data.to! } : item
            )
          );
        }
      } else if (msg.type === "item:created" || msg.type === "item:closed") {
        // Trigger a background refetch so the new/closed item appears
        fetchItems().catch(() => {
          // Non-fatal: next polling cycle will catch it
        });
      }
    },
    [fetchItems]
  );

  const grouped = groupItemsByStatus(items);

  return {
    grouped,
    items,
    loading,
    error,
    moveItem,
    refetch: fetchItems,
    applyWsMessage,
  };
}
