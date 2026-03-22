import type { BoardStatus } from "./index";

/** Payload shapes for each sync operation type. */
export interface SyncCreatePayload {
  itemId: number;
  title: string;
  type: string;
  body?: string;
  labels?: string[];
  parentExternalId?: string;
}

export interface SyncUpdatePayload {
  itemId: number;
  externalId: string;
  changes: {
    title?: string;
    body?: string;
  };
}

export interface SyncClosePayload {
  itemId: number;
  externalId: string;
}

export interface SyncSetStatusPayload {
  itemId: number;
  externalId: string;
  status: BoardStatus;
}

export interface SyncCommentPayload {
  itemId: number;
  externalId: string;
  body: string;
  author: string;
}

export interface SyncLinkChildPayload {
  parentItemId: number;
  childItemId: number;
  parentExternalId: string;
  childExternalId: string;
}

/** Union of all sync payloads, discriminated by operation field in the queue row. */
export type SyncPayload =
  | SyncCreatePayload
  | SyncUpdatePayload
  | SyncClosePayload
  | SyncSetStatusPayload
  | SyncCommentPayload
  | SyncLinkChildPayload;

/**
 * External PM adapter interface for the sync engine.
 * Each method corresponds to a sync operation type.
 * Implementations call the external system (GitHub, Jira, etc.).
 */
export interface ExternalPmAdapter {
  createItem(payload: SyncCreatePayload): Promise<{ externalId: string; url: string }>;
  updateItem(payload: SyncUpdatePayload): Promise<void>;
  closeItem(payload: SyncClosePayload): Promise<void>;
  setStatus(payload: SyncSetStatusPayload): Promise<void>;
  addComment(payload: SyncCommentPayload): Promise<void>;
  linkChild(payload: SyncLinkChildPayload): Promise<void>;
}

/** Options for the SyncWorker polling loop. */
export interface SyncWorkerOptions {
  /** Polling interval in milliseconds. Default: 5000 (5 seconds). */
  pollIntervalMs?: number;
  /** Maximum retry attempts before dead-lettering. Default: 5. */
  maxRetries?: number;
}
