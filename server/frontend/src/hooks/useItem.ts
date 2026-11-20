/**
 * useItem — React hook for fetching a single work item with its details.
 *
 * Fetches:
 * - Item metadata (GET /api/items/:id)
 * - Comments (GET /api/items/:id/comments)
 * - Telemetry records (GET /api/items/:id/telemetry)
 * - Children items (GET /api/items/:id/children)
 * - Parent item (GET /api/items/:id if parentId exists)
 */

import { useState, useEffect } from "react";
import type { WorkItem, Comment, TelemetryRecord } from "../lib/types";
import { api, ApiClientError } from "../lib/api";

export interface ItemDetailData {
  item: WorkItem;
  parent: WorkItem | null;
  children: WorkItem[];
  comments: Comment[];
  telemetry: TelemetryRecord[];
}

export interface UseItemResult {
  data: ItemDetailData | null;
  loading: boolean;
  error: string | null;
  /** Reload item data from the server. */
  refetch: () => void;
}

/**
 * Fetches a work item and all associated data (comments, telemetry, hierarchy).
 *
 * @param id - Numeric item ID (string from route params)
 */
export function useItem(id: string | undefined): UseItemResult {
  const [data, setData] = useState<ItemDetailData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [version, setVersion] = useState(0);

  useEffect(() => {
    if (!id) {
      setLoading(false);
      setError("No item ID provided");
      return;
    }

    const numId = parseInt(id, 10);
    if (isNaN(numId)) {
      setLoading(false);
      setError(`Invalid item ID: ${id}`);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    async function load() {
      try {
        // Fetch the primary item first — bail early if it 404s.
        const item = await api.getItem(numId);

        // Parallel secondary fetches — fail gracefully so a missing telemetry
        // record doesn't hide a valid item.
        const [comments, telemetry, children, parent] = await Promise.all([
          api.listItemComments(numId).catch(() => [] as Comment[]),
          api.getItemTelemetry(numId).catch(() => [] as TelemetryRecord[]),
          api.listChildren(numId).catch(() => [] as WorkItem[]),
          item.parentId
            ? api.getItem(item.parentId).catch(() => null)
            : Promise.resolve(null),
        ]);

        if (!cancelled) {
          setData({ item, parent, children, comments, telemetry });
          setError(null);
        }
      } catch (err) {
        if (!cancelled) {
          if (err instanceof ApiClientError) {
            setError(
              err.status === 404
                ? `Item ${id} not found`
                : `Failed to load item: ${err.message}`
            );
          } else {
            setError("Failed to load item");
          }
          setData(null);
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, [id, version]);

  function refetch() {
    setVersion((v) => v + 1);
  }

  return { data, loading, error, refetch };
}
