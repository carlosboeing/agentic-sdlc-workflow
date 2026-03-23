/**
 * useDocComments hook — fetches and manages comments for a document.
 *
 * Returns:
 *   comments     — all comments for the document, indexed by anchor
 *   loading      — true while the request is in flight
 *   error        — error message string, or null on success
 *   addComment   — function to post a new comment
 *   refreshComments — refetch comments from the server
 *
 * Comments are grouped by anchor for efficient lookup when rendering
 * inline threads alongside paragraphs. The "detached" group contains
 * comments whose anchors no longer exist in the document.
 */

import { useState, useEffect, useCallback } from "react";
import { api } from "../lib/api";
import type { Comment } from "../lib/types";

/** Comments grouped by their anchor ID. */
export interface GroupedComments {
  /** Map from anchor ID to comments at that anchor. */
  byAnchor: Map<string, Comment[]>;
  /** Comments with no anchor (document-level). */
  unanchored: Comment[];
}

interface UseDocCommentsResult {
  comments: Comment[];
  grouped: GroupedComments;
  loading: boolean;
  error: string | null;
  addComment: (
    body: string,
    author?: string,
    anchor?: string,
    threadId?: string
  ) => Promise<Comment | null>;
  refreshComments: () => void;
}

/**
 * Group comments by anchor ID for inline rendering.
 * Thread replies are grouped under their parent's anchor.
 */
function groupComments(comments: Comment[]): GroupedComments {
  const byAnchor = new Map<string, Comment[]>();
  const unanchored: Comment[] = [];

  for (const comment of comments) {
    if (comment.anchor) {
      const existing = byAnchor.get(comment.anchor) ?? [];
      existing.push(comment);
      byAnchor.set(comment.anchor, existing);
    } else {
      unanchored.push(comment);
    }
  }

  return { byAnchor, unanchored };
}

export function useDocComments(
  documentPath: string | null
): UseDocCommentsResult {
  const [comments, setComments] = useState<Comment[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [refreshKey, setRefreshKey] = useState(0);

  const refreshComments = useCallback(() => {
    setRefreshKey((k) => k + 1);
  }, []);

  useEffect(() => {
    if (!documentPath) {
      setComments([]);
      setLoading(false);
      setError(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    api
      .listDocumentComments(documentPath)
      .then((data) => {
        if (!cancelled) {
          setComments(data);
          setLoading(false);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          const msg =
            err instanceof Error ? err.message : "Failed to load comments";
          setError(msg);
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [documentPath, refreshKey]);

  const addComment = useCallback(
    async (
      body: string,
      author = "human",
      anchor?: string,
      threadId?: string
    ): Promise<Comment | null> => {
      if (!documentPath) return null;

      try {
        const comment = await api.addDocumentComment(
          documentPath,
          body,
          author,
          anchor,
          threadId
        );
        // Refresh comment list after adding
        setRefreshKey((k) => k + 1);
        return comment;
      } catch (err: unknown) {
        const msg =
          err instanceof Error ? err.message : "Failed to add comment";
        setError(msg);
        return null;
      }
    },
    [documentPath]
  );

  const grouped = groupComments(comments);

  return {
    comments,
    grouped,
    loading,
    error,
    addComment,
    refreshComments,
  };
}
