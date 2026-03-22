/**
 * useWebSocket hook — manages a WebSocket connection with auto-reconnect.
 *
 * Features:
 * - Connects to ws://localhost:<port>/ws on mount
 * - Exponential backoff reconnect on disconnect (1s, 2s, 4s, 8s... max 30s)
 * - Connection status indicator: "connected" | "disconnected" | "reconnecting"
 * - Parses incoming messages as ActivityMessage objects
 * - Calls onMessage callback for each message
 * - Returns connection status and latest message
 */

import { useState, useEffect, useRef, useCallback } from "react";
import type { WsMessage, ActivityEventType } from "../lib/types";

/** ActivityMessage matches WsMessage — re-exported for convenience. */
export type ActivityMessage = WsMessage & {
  type: ActivityEventType | "connection:established";
};

export type ConnectionStatus = "connected" | "disconnected" | "reconnecting";

export interface UseWebSocketOptions {
  /** WebSocket URL. Defaults to ws://localhost relative to current location. */
  url?: string;
  /** Called for each message received. */
  onMessage?: (msg: ActivityMessage) => void;
  /** Maximum reconnect delay in milliseconds. Default: 30000 (30s). */
  maxReconnectDelayMs?: number;
  /** Whether to connect automatically. Default: true. */
  autoConnect?: boolean;
}

export interface UseWebSocketResult {
  /** Current connection status. */
  status: ConnectionStatus;
  /** Most recent message received, or null. */
  lastMessage: ActivityMessage | null;
  /** Manually disconnect (stops auto-reconnect). */
  disconnect: () => void;
  /** Manually reconnect (resets reconnect backoff). */
  reconnect: () => void;
}

const BASE_DELAY_MS = 1000;
const MAX_DELAY_MS = 30_000;

function getWsUrl(): string {
  const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${window.location.host}/ws`;
}

export function useWebSocket(options: UseWebSocketOptions = {}): UseWebSocketResult {
  const {
    url,
    onMessage,
    maxReconnectDelayMs = MAX_DELAY_MS,
    autoConnect = true,
  } = options;

  const [status, setStatus] = useState<ConnectionStatus>("disconnected");
  const [lastMessage, setLastMessage] = useState<ActivityMessage | null>(null);

  // Refs so callbacks close over stable references
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const attemptRef = useRef(0);
  const intentionalCloseRef = useRef(false);
  const onMessageRef = useRef(onMessage);
  onMessageRef.current = onMessage;

  const clearTimer = useCallback(() => {
    if (reconnectTimerRef.current !== null) {
      clearTimeout(reconnectTimerRef.current);
      reconnectTimerRef.current = null;
    }
  }, []);

  const connect = useCallback(() => {
    // Close any existing connection
    if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
      wsRef.current.close();
    }

    const wsUrl = url ?? getWsUrl();
    const ws = new WebSocket(wsUrl);
    wsRef.current = ws;

    ws.onopen = () => {
      attemptRef.current = 0;
      setStatus("connected");
    };

    ws.onmessage = (event: MessageEvent<string>) => {
      try {
        const msg = JSON.parse(event.data) as ActivityMessage;
        setLastMessage(msg);
        onMessageRef.current?.(msg);
      } catch {
        // Ignore non-JSON messages
      }
    };

    ws.onclose = () => {
      wsRef.current = null;
      if (intentionalCloseRef.current) {
        setStatus("disconnected");
        return;
      }

      setStatus("reconnecting");
      const delay = Math.min(
        BASE_DELAY_MS * Math.pow(2, attemptRef.current),
        maxReconnectDelayMs
      );
      attemptRef.current += 1;

      reconnectTimerRef.current = setTimeout(() => {
        connect();
      }, delay);
    };

    ws.onerror = () => {
      // onclose fires after onerror, so reconnect is handled there
    };
  }, [url, maxReconnectDelayMs]);

  const disconnect = useCallback(() => {
    intentionalCloseRef.current = true;
    clearTimer();
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
    setStatus("disconnected");
  }, [clearTimer]);

  const reconnect = useCallback(() => {
    intentionalCloseRef.current = false;
    attemptRef.current = 0;
    clearTimer();
    connect();
  }, [connect, clearTimer]);

  // Auto-connect on mount
  useEffect(() => {
    if (!autoConnect) return;
    intentionalCloseRef.current = false;
    connect();

    return () => {
      intentionalCloseRef.current = true;
      clearTimer();
      if (wsRef.current) {
        wsRef.current.close();
        wsRef.current = null;
      }
    };
  }, [autoConnect, connect, clearTimer]);

  return { status, lastMessage, disconnect, reconnect };
}
