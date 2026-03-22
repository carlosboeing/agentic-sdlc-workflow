/**
 * ActivityFeed — real-time event log panel.
 *
 * Shows activity events in reverse chronological order (newest at top).
 * Connected via WebSocket for live updates, with backfill of recent events
 * on connect. The panel is collapsible via a toggle button.
 *
 * Features:
 * - Connection status indicator (green dot / amber dot / red dot)
 * - Backfill of last 50 events on connect
 * - Live events prepended to the top
 * - Collapsible panel (controlled by parent via isOpen prop)
 */

import { useState, useEffect, useCallback } from "react";
import { useWebSocket, type ActivityMessage } from "../hooks/useWebSocket";
import { ActivityItem } from "./ActivityItem";
import type { ActivityEvent } from "../lib/types";

// ---------------------------------------------------------------------------
// Connection status indicator
// ---------------------------------------------------------------------------

function ConnectionIndicator({ status }: { status: "connected" | "disconnected" | "reconnecting" }) {
  const config = {
    connected: { color: "bg-emerald-500", label: "Connected" },
    disconnected: { color: "bg-red-400", label: "Disconnected" },
    reconnecting: { color: "bg-amber-400", label: "Reconnecting…" },
  }[status];

  return (
    <span className="flex items-center gap-1.5 text-xs text-gray-500">
      <span
        className={`inline-block h-2 w-2 rounded-full ${config.color} ${
          status === "reconnecting" ? "animate-pulse" : ""
        }`}
        aria-label={config.label}
      />
      {config.label}
    </span>
  );
}

// ---------------------------------------------------------------------------
// ActivityFeed component
// ---------------------------------------------------------------------------

export interface ActivityFeedProps {
  /** Whether the panel is visible. */
  isOpen: boolean;
  /** Called when the toggle button is clicked. */
  onToggle: () => void;
}

export function ActivityFeed({ isOpen, onToggle }: ActivityFeedProps) {
  // Live events received since mount (newest first)
  const [liveEvents, setLiveEvents] = useState<Array<{ message: ActivityMessage; receivedAt: string }>>([]);
  // Backfill events from connection:established (oldest first in source, reversed for display)
  const [backfillEvents, setBackfillEvents] = useState<ActivityEvent[]>([]);

  const handleMessage = useCallback((msg: ActivityMessage) => {
    if (msg.type === "connection:established") {
      // Server sends backfill in the data.recentEvents array (newest first, from ORDER BY id DESC)
      const data = msg.data as { recentEvents: ActivityEvent[] };
      setBackfillEvents(data.recentEvents ?? []);
      setLiveEvents([]); // reset live on reconnect
    } else {
      setLiveEvents((prev) => [
        { message: msg, receivedAt: new Date().toISOString() },
        ...prev,
      ]);
    }
  }, []);

  const { status } = useWebSocket({ onMessage: handleMessage });

  return (
    <div
      className={`flex flex-col border-l border-gray-200 bg-white transition-all duration-200 ${
        isOpen ? "w-72 shrink-0" : "w-10 shrink-0"
      }`}
      aria-label="Activity Feed"
    >
      {/* Header with toggle */}
      <div className="flex items-center justify-between h-10 px-2 border-b border-gray-200 shrink-0">
        {isOpen && (
          <span className="text-xs font-medium text-gray-700 truncate mr-2">
            Activity
          </span>
        )}
        <button
          type="button"
          onClick={onToggle}
          className="p-1 rounded hover:bg-gray-100 text-gray-500 hover:text-gray-700"
          aria-label={isOpen ? "Collapse activity feed" : "Expand activity feed"}
          title={isOpen ? "Collapse" : "Activity Feed"}
        >
          {isOpen ? (
            // Chevron right (collapse)
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          ) : (
            // Chevron left (expand)
            <svg className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          )}
        </button>
      </div>

      {/* Panel content — only shown when open */}
      {isOpen && (
        <>
          {/* Connection status */}
          <div className="px-3 py-1.5 border-b border-gray-100">
            <ConnectionIndicator status={status} />
          </div>

          {/* Events list */}
          <div className="flex-1 overflow-y-auto">
            {liveEvents.length === 0 && backfillEvents.length === 0 ? (
              <p className="text-xs text-gray-400 text-center py-6 px-3">
                No activity yet.
              </p>
            ) : (
              <div className="py-1">
                {/* Live events (newest first) */}
                {liveEvents.map((entry, i) => (
                  <ActivityItem
                    key={`live-${i}`}
                    variant="ws"
                    message={entry.message}
                    receivedAt={entry.receivedAt}
                  />
                ))}
                {/* Backfill events (already ordered newest first from server) */}
                {backfillEvents.map((event) => (
                  <ActivityItem
                    key={`backfill-${event.id}`}
                    variant="log"
                    event={event}
                  />
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
