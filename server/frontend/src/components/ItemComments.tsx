/**
 * ItemComments — wraps CommentList with data-fetching state for an item.
 *
 * Manages the add-comment mutation and passes loading state to CommentList.
 */

import { useState } from "react";
import type { Comment } from "../lib/types";
import { CommentList } from "./CommentList";
import { api } from "../lib/api";

interface ItemCommentsProps {
  itemId: number;
  initialComments: Comment[];
}

export function ItemComments({ itemId, initialComments }: ItemCommentsProps) {
  const [comments, setComments] = useState<Comment[]>(initialComments);
  const [posting, setPosting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleAddComment(body: string) {
    setPosting(true);
    setError(null);
    try {
      const newComment = await api.addItemComment(itemId, body);
      setComments((prev) => [...prev, newComment]);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to post comment");
    } finally {
      setPosting(false);
    }
  }

  return (
    <div>
      {error && (
        <p className="text-xs text-red-500 mb-3">
          Error: {error}
        </p>
      )}
      <CommentList
        comments={comments}
        onAddComment={handleAddComment}
        loading={posting}
      />
    </div>
  );
}
