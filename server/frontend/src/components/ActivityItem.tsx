/**
 * ActivityItem — renders a single activity event in the feed.
 *
 * Displays the event type as a badge, a human-readable description,
 * and the relative timestamp.
 */

import type { ActivityEvent } from "../lib/types";
import type { ActivityMessage } from "../hooks/useWebSocket";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatRelativeTime(isoDate: string): string {
  const diff = Date.now() - new Date(isoDate).getTime();
  if (diff < 60_000) return "just now";
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)}m ago`;
  if (diff < 86_400_000) return `${Math.floor(diff / 3_600_000)}h ago`;
  return new Date(isoDate).toLocaleDateString();
}

/** Map event type to a short label and color class. */
function getEventMeta(eventType: string): { label: string; colorClass: string } {
  switch (eventType) {
    case "item:created":
      return { label: "created", colorClass: "bg-emerald-100 text-emerald-700" };
    case "item:updated":
      return { label: "updated", colorClass: "bg-blue-100 text-blue-700" };
    case "item:closed":
      return { label: "closed", colorClass: "bg-gray-100 text-gray-600" };
    case "status:changed":
      return { label: "status", colorClass: "bg-violet-100 text-violet-700" };
    case "comment:added":
      return { label: "comment", colorClass: "bg-amber-100 text-amber-700" };
    case "telemetry:posted":
      return { label: "telemetry", colorClass: "bg-cyan-100 text-cyan-700" };
    case "connection:established":
      return { label: "connected", colorClass: "bg-green-100 text-green-700" };
    default:
      return { label: eventType.split(":")[1] ?? eventType, colorClass: "bg-gray-100 text-gray-600" };
  }
}

function describeEvent(eventType: string, payload: string | unknown): string {
  let data: Record<string, unknown> = {};
  if (typeof payload === "string") {
    try {
      data = JSON.parse(payload) as Record<string, unknown>;
    } catch {
      return eventType;
    }
  } else if (payload && typeof payload === "object") {
    data = payload as Record<string, unknown>;
  }

  switch (eventType) {
    case "item:created":
      return `Item #${String(data.id ?? "?")} created: ${String(data.title ?? "")}`;
    case "item:updated":
      return `Item #${String(data.id ?? "?")} updated`;
    case "item:closed":
      return `Item #${String(data.id ?? "?")} closed`;
    case "status:changed": {
      const itemId = data.itemId ?? data.item_id;
      return `Item #${String(itemId ?? "?")} → ${String(data.to ?? data.newStatus ?? "")}`;
    }
    case "comment:added":
      return `Comment on #${String(data.itemId ?? data.item_id ?? "?")} by ${String(data.author ?? "?")}`;
    case "telemetry:posted":
      return `Telemetry posted for #${String(data.itemId ?? data.item_id ?? "?")}`;
    case "connection:established":
      return "Connected to server";
    default:
      return eventType;
  }
}

// ---------------------------------------------------------------------------
// Props types
// ---------------------------------------------------------------------------

/** Props for a persisted activity event (from the REST API backfill). */
interface ActivityItemFromLog {
  variant: "log";
  event: ActivityEvent;
}

/** Props for a live WebSocket event. */
interface ActivityItemFromWs {
  variant: "ws";
  message: ActivityMessage;
  receivedAt: string;
}

export type ActivityItemProps = ActivityItemFromLog | ActivityItemFromWs;

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function ActivityItem(props: ActivityItemProps) {
  let eventType: string;
  let description: string;
  let timestamp: string;

  if (props.variant === "log") {
    eventType = props.event.event_type;
    description = describeEvent(eventType, props.event.payload);
    timestamp = props.event.created_at;
  } else {
    eventType = props.message.type;
    description = describeEvent(eventType, props.message.data);
    timestamp = props.receivedAt;
  }

  const { label, colorClass } = getEventMeta(eventType);

  return (
    <div className="flex items-start gap-2 px-3 py-2 hover:bg-gray-50 rounded-md">
      {/* Event type badge */}
      <span
        className={`shrink-0 mt-0.5 inline-block rounded px-1.5 py-0.5 text-xs font-medium ${colorClass}`}
      >
        {label}
      </span>

      {/* Description */}
      <p className="flex-1 text-xs text-gray-700 leading-5 break-words min-w-0">
        {description}
      </p>

      {/* Timestamp */}
      <time
        className="shrink-0 text-xs text-gray-400"
        title={timestamp}
      >
        {formatRelativeTime(timestamp)}
      </time>
    </div>
  );
}
