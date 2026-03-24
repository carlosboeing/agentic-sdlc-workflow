/**
 * CommentThread — inline comment thread anchored to a paragraph.
 *
 * Displays a list of comments for a specific anchor, organized as:
 * - Top-level comments (thread_id is null) shown first
 * - Replies (thread_id matches a parent comment id) shown indented below their parent
 *
 * Each comment shows author, timestamp, and body. A reply form
 * appears when the user clicks "Reply" on a comment.
 */

import { useState } from "react";
import type { Comment } from "../lib/types";
import { CommentForm } from "./CommentForm";

interface CommentThreadProps {
  /** Comments for this anchor, already filtered. */
  comments: Comment[];
  /** Anchor ID this thread belongs to. */
  anchor: string;
  /** Called to post a new comment or reply. */
  onAddComment: (
    body: string,
    author: string,
    anchor: string,
    threadId?: string
  ) => Promise<void>;
  /** Called when the thread should be closed. */
  onClose?: () => void;
}

/** Format an ISO timestamp to a human-readable relative or short date. */
function formatTimestamp(iso: string): string {
  const date = new Date(iso);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMin = Math.floor(diffMs / 60000);

  if (diffMin < 1) return "just now";
  if (diffMin < 60) return `${diffMin}m ago`;

  const diffHours = Math.floor(diffMin / 60);
  if (diffHours < 24) return `${diffHours}h ago`;

  const diffDays = Math.floor(diffHours / 24);
  if (diffDays < 7) return `${diffDays}d ago`;

  return date.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: date.getFullYear() !== now.getFullYear() ? "numeric" : undefined,
  });
}

function CommentBubble({
  comment,
  isReply,
  onReply,
}: {
  comment: Comment;
  isReply?: boolean;
  onReply?: () => void;
}) {
  return (
    <div
      className={`${isReply ? "ml-4 border-l-2 border-gray-200 pl-3" : ""} py-2`}
    >
      <div className="flex items-center gap-2 text-xs">
        <span className="font-medium text-gray-700">{comment.author}</span>
        <span className="text-gray-400">{formatTimestamp(comment.createdAt)}</span>
      </div>
      <p className="mt-1 text-sm text-gray-600 leading-relaxed">
        {comment.body}
      </p>
      {!isReply && onReply && (
        <button
          onClick={onReply}
          className="mt-1 text-xs text-blue-500 hover:text-blue-700"
        >
          Reply
        </button>
      )}
    </div>
  );
}

export function CommentThread({
  comments,
  anchor,
  onAddComment,
  onClose,
}: CommentThreadProps) {
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [showNewComment, setShowNewComment] = useState(comments.length === 0);

  // Separate top-level comments from replies
  const topLevel = comments.filter((c) => c.threadId === null);
  const replies = comments.filter((c) => c.threadId !== null);

  // Group replies by parent thread_id
  const repliesByParent = new Map<string, Comment[]>();
  for (const reply of replies) {
    if (reply.threadId) {
      const existing = repliesByParent.get(reply.threadId) ?? [];
      existing.push(reply);
      repliesByParent.set(reply.threadId, existing);
    }
  }

  async function handleNewComment(body: string, author: string) {
    await onAddComment(body, author, anchor);
    setShowNewComment(false);
  }

  async function handleReply(body: string, author: string) {
    if (replyingTo) {
      await onAddComment(body, author, anchor, replyingTo);
      setReplyingTo(null);
    }
  }

  return (
    <div className="rounded-lg border border-gray-200 bg-white shadow-sm p-3 min-w-[280px] max-w-[360px]">
      {/* Header */}
      <div className="flex items-center justify-between mb-2 pb-2 border-b border-gray-100">
        <h4 className="text-xs font-semibold text-gray-500 uppercase tracking-wide">
          Comments
        </h4>
        {onClose && (
          <button
            onClick={onClose}
            className="text-gray-400 hover:text-gray-600 text-sm leading-none"
            aria-label="Close thread"
          >
            x
          </button>
        )}
      </div>

      {/* Comment list */}
      {topLevel.length === 0 && !showNewComment ? (
        <p className="text-xs text-gray-400 italic py-2">No comments yet.</p>
      ) : (
        <div className="space-y-1 max-h-80 overflow-y-auto">
          {topLevel.map((comment) => (
            <div key={comment.id}>
              <CommentBubble
                comment={comment}
                onReply={() => setReplyingTo(String(comment.id))}
              />
              {/* Replies to this comment */}
              {repliesByParent.get(String(comment.id))?.map((reply) => (
                <CommentBubble key={reply.id} comment={reply} isReply />
              ))}
              {/* Reply form for this comment */}
              {replyingTo === String(comment.id) && (
                <div className="ml-4">
                  <CommentForm
                    onSubmit={handleReply}
                    onCancel={() => setReplyingTo(null)}
                    isReply
                    autoFocus
                  />
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* New comment form */}
      {showNewComment ? (
        <CommentForm
          onSubmit={handleNewComment}
          onCancel={
            comments.length > 0
              ? () => setShowNewComment(false)
              : undefined
          }
          autoFocus
        />
      ) : (
        <button
          onClick={() => setShowNewComment(true)}
          className="mt-2 w-full rounded border border-dashed border-gray-300 py-1.5 text-xs text-gray-400 hover:border-gray-400 hover:text-gray-500"
        >
          + Add comment
        </button>
      )}
    </div>
  );
}
