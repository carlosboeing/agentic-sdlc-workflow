/**
 * IssueMapper: converts raw GitHub GraphQL issue nodes into the typed
 * records expected by the SQLite schema (via DatabaseUpserter).
 *
 * This module is intentionally free of I/O and database dependencies —
 * it is a pure data transformation layer, making it trivially testable.
 */

import type { ItemType, BoardStatus, ItemState } from "../types";

// ---------------------------------------------------------------------------
// GitHub GraphQL types
// ---------------------------------------------------------------------------

/** A single field value node from ProjectV2ItemFieldSingleSelectValue. */
export interface ProjectV2FieldValue {
  name: string;
  field: {
    name: string;
  };
}

/** Pagination info attached to comment connections. */
export interface PageInfo {
  hasNextPage: boolean;
  endCursor: string | null;
}

/** A single comment node from the GitHub GraphQL API. */
export interface GitHubCommentNode {
  body: string;
  author: { login: string } | null;
  createdAt: string;
  updatedAt: string;
}

/** A project item node (board membership) from the GitHub GraphQL API. */
export interface GitHubProjectItemNode {
  fieldValues: {
    nodes: ProjectV2FieldValue[];
  };
}

/** A label node from the GitHub GraphQL API. */
export interface GitHubLabelNode {
  name: string;
}

/**
 * A single issue node returned by the GitHub GraphQL issues query.
 * Corresponds to the query shape defined in the design doc (section 4.1).
 */
export interface GitHubIssueNode {
  number: number;
  title: string;
  body: string | null;
  state: "OPEN" | "CLOSED";
  createdAt: string;
  updatedAt: string;
  url: string;
  parent: { number: number } | null;
  labels: {
    nodes: GitHubLabelNode[];
  };
  projectItems: {
    nodes: GitHubProjectItemNode[];
  };
  comments: {
    totalCount: number;
    pageInfo: PageInfo;
    nodes: GitHubCommentNode[];
  };
}

// ---------------------------------------------------------------------------
// Mapper output types
// ---------------------------------------------------------------------------

/** A single mapped comment ready for database upsert. */
export interface MappedComment {
  body: string;
  author: string;
  createdAt: string;
  updatedAt: string;
}

/** The output of IssueMapper.mapIssue() — one typed record per GitHub issue. */
export interface MappedIssue {
  item: {
    id: number;
    title: string;
    body: string | null;
    type: ItemType;
    status: BoardStatus;
    state: ItemState;
    externalId: string;
    externalUrl: string;
    createdAt: string;
    updatedAt: string;
  };
  labels: string[];
  parentNumber: number | null;
  comments: MappedComment[];
}

// ---------------------------------------------------------------------------
// Status name -> BoardStatus mapping (case-insensitive)
// ---------------------------------------------------------------------------

const STATUS_MAP: Record<string, BoardStatus> = {
  "backlog": "backlog",
  "ready": "ready",
  "in progress": "in-progress",
  "in review": "in-review",
  "done": "done",
};

// ---------------------------------------------------------------------------
// IssueMapper
// ---------------------------------------------------------------------------

/**
 * Maps GitHub GraphQL issue nodes to the typed records expected by
 * DatabaseUpserter. Stateless — safe to share across requests.
 */
export class IssueMapper {
  /**
   * Convert a single GitHub issue node to a MappedIssue.
   *
   * Type derivation:
   *   hierarchy/backlog -> "backlog"
   *   hierarchy/epic    -> "epic"
   *   hierarchy/story   -> "story"
   *   type/docs (no hierarchy label) -> "docs"
   *   default -> "story"
   *
   * Status derivation:
   *   Extracts ProjectV2ItemFieldSingleSelectValue where field.name is "Status".
   *   Maps case-insensitively. Defaults to "backlog" when not on board.
   */
  mapIssue(node: GitHubIssueNode): MappedIssue {
    const labelNames = node.labels.nodes.map((l) => l.name);

    return {
      item: {
        id: node.number,
        title: node.title,
        body: node.body,
        type: this._deriveType(labelNames),
        status: this._deriveStatus(node.projectItems.nodes, node.state),
        state: node.state === "OPEN" ? "open" : "closed",
        externalId: String(node.number),
        externalUrl: node.url,
        createdAt: node.createdAt,
        updatedAt: node.updatedAt,
      },
      labels: labelNames,
      parentNumber: node.parent?.number ?? null,
      comments: node.comments.nodes.map((c) => ({
        body: c.body,
        author: c.author?.login ?? "unknown",
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      })),
    };
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  private _deriveType(labelNames: string[]): ItemType {
    for (const name of labelNames) {
      if (name === "hierarchy/backlog") return "backlog";
      if (name === "hierarchy/epic") return "epic";
      if (name === "hierarchy/story") return "story";
    }

    // No hierarchy label — check for type/docs
    if (labelNames.includes("type/docs")) return "docs";

    // Default
    return "story";
  }

  private _deriveStatus(
    projectItems: GitHubProjectItemNode[],
    issueState: string
  ): BoardStatus {
    // Fallback: closed issues without board status → "done"
    const fallback: BoardStatus = issueState === "CLOSED" ? "done" : "backlog";

    if (projectItems.length === 0) return fallback;

    // Use the first project item (issues belong to at most one relevant project)
    const fieldValues = projectItems[0].fieldValues.nodes;

    for (const fv of fieldValues) {
      if (fv.field?.name === "Status" && fv.name) {
        const normalized = fv.name.toLowerCase();
        const mapped = STATUS_MAP[normalized];
        return mapped ?? fallback;
      }
    }

    // Status field not found in fieldValues
    return fallback;
  }
}
