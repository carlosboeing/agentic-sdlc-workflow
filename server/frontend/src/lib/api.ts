/**
 * HTTP client wrapper for the Workflow Runtime Service API.
 *
 * All methods return typed responses. Errors are thrown as ApiClientError
 * instances with the HTTP status code and server error message included.
 *
 * Usage:
 *   const client = createApiClient();         // uses /api base path (relative)
 *   const client = createApiClient("http://localhost:3117");  // absolute URL
 */

import type {
  WorkItem,
  Comment,
  TelemetryRecord,
  ActivityEvent,
  Label,
  HealthResponse,
  ListItemsParams,
  CreateItemPayload,
  UpdateItemPayload,
  SetStatusPayload,
  BoardStatus,
  DocumentEntry,
  DocumentContent,
} from "./types";

// ---------------------------------------------------------------------------
// Error class
// ---------------------------------------------------------------------------

export class ApiClientError extends Error {
  constructor(
    message: string,
    public readonly status: number,
    public readonly body?: unknown
  ) {
    super(message);
    this.name = "ApiClientError";
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

async function parseResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    let body: unknown;
    try {
      body = await res.json();
    } catch {
      body = await res.text();
    }
    const message =
      typeof body === "object" && body !== null && "error" in body
        ? String((body as { error: unknown }).error)
        : `HTTP ${res.status}`;
    throw new ApiClientError(message, res.status, body);
  }
  // 204 No Content — the server intentionally sends no body (common for DELETE).
  // Attempting res.json() on an empty response throws "Unexpected end of JSON input".
  if (res.status === 204 || res.headers.get("content-length") === "0") {
    return undefined as T;
  }
  return res.json() as Promise<T>;
}

function buildQuery(params: Record<string, unknown>): string {
  const entries = Object.entries(params).filter(
    ([, v]) => v !== undefined && v !== null
  );
  if (entries.length === 0) return "";
  const qs = entries.map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`).join("&");
  return `?${qs}`;
}

// ---------------------------------------------------------------------------
// API client factory
// ---------------------------------------------------------------------------

export interface ApiClient {
  // Health
  getHealth(): Promise<HealthResponse>;

  // Items
  listItems(params?: ListItemsParams): Promise<WorkItem[]>;
  getItem(id: number): Promise<WorkItem>;
  createItem(payload: CreateItemPayload): Promise<WorkItem>;
  updateItem(id: number, payload: UpdateItemPayload): Promise<WorkItem>;
  closeItem(id: number): Promise<WorkItem>;
  setItemStatus(id: number, status: BoardStatus): Promise<WorkItem>;
  linkChild(parentId: number, childId: number): Promise<void>;
  listChildren(id: number): Promise<WorkItem[]>;

  // Comments
  listItemComments(itemId: number): Promise<Comment[]>;
  addItemComment(itemId: number, body: string, author?: string): Promise<Comment>;

  // Telemetry
  getItemTelemetry(itemId: number): Promise<TelemetryRecord[]>;

  // Labels
  listLabels(): Promise<Label[]>;

  // Activity
  listActivity(limit?: number): Promise<ActivityEvent[]>;

  // Documents
  listDocuments(): Promise<DocumentEntry[]>;
  getDocument(path: string): Promise<DocumentContent>;
  listDocumentComments(path: string): Promise<Comment[]>;
  addDocumentComment(
    path: string,
    body: string,
    author?: string,
    anchor?: string,
    threadId?: string
  ): Promise<Comment>;
}

export function createApiClient(baseUrl = ""): ApiClient {
  const base = baseUrl.replace(/\/$/, "");

  async function get<T>(path: string): Promise<T> {
    const res = await fetch(`${base}${path}`);
    return parseResponse<T>(res);
  }

  async function post<T>(path: string, body: unknown): Promise<T> {
    const res = await fetch(`${base}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return parseResponse<T>(res);
  }

  async function patch<T>(path: string, body: unknown): Promise<T> {
    const res = await fetch(`${base}${path}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    return parseResponse<T>(res);
  }

  async function del<T>(path: string): Promise<T> {
    const res = await fetch(`${base}${path}`, { method: "DELETE" });
    return parseResponse<T>(res);
  }

  return {
    getHealth: () => get<HealthResponse>("/api/health"),

    listItems: (params) => {
      const qs = params ? buildQuery(params as Record<string, unknown>) : "";
      return get<WorkItem[]>(`/api/items${qs}`);
    },

    getItem: (id) => get<WorkItem>(`/api/items/${id}`),

    createItem: (payload) => post<WorkItem>("/api/items", payload),

    updateItem: (id, payload) => patch<WorkItem>(`/api/items/${id}`, payload),

    closeItem: (id) => del<WorkItem>(`/api/items/${id}`),

    setItemStatus: (id, status: BoardStatus) => {
      const payload: SetStatusPayload = { status };
      return post<WorkItem>(`/api/items/${id}/status`, payload);
    },

    linkChild: (parentId, childId) =>
      post<void>(`/api/items/${parentId}/children`, { childId }),

    listChildren: (id) => get<WorkItem[]>(`/api/items/${id}/children`),

    listItemComments: (itemId) =>
      get<Comment[]>(`/api/items/${itemId}/comments`),

    addItemComment: (itemId, body, author = "human") =>
      post<Comment>(`/api/items/${itemId}/comments`, { body, author }),

    getItemTelemetry: (itemId) =>
      get<TelemetryRecord[]>(`/api/items/${itemId}/telemetry`),

    listLabels: () => get<Label[]>("/api/labels"),

    listActivity: (limit) => {
      const qs = limit !== undefined ? buildQuery({ limit }) : "";
      return get<ActivityEvent[]>(`/api/activity${qs}`);
    },

    listDocuments: () => get<DocumentEntry[]>("/api/documents"),

    getDocument: (path) =>
      get<DocumentContent>(`/api/documents/${encodeDocPath(path)}`),

    listDocumentComments: (path) =>
      get<Comment[]>(`/api/documents/${encodeDocPath(path)}/comments`),

    addDocumentComment: (path, body, author = "human", anchor, threadId) =>
      post<Comment>(`/api/documents/${encodeDocPath(path)}/comments`, {
        body,
        author,
        ...(anchor !== undefined ? { anchor } : {}),
        ...(threadId !== undefined ? { thread_id: threadId } : {}),
      }),
  };
}

/**
 * Encode a document path for use in URLs.
 * Encodes each segment individually to allow slashes in the path.
 */
function encodeDocPath(path: string): string {
  return path
    .split("/")
    .map((segment) => encodeURIComponent(segment))
    .join("/");
}

/** Default API client using relative paths (same-origin). */
export const api = createApiClient();
