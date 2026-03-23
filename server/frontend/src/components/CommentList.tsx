/**
 * CommentList — renders item comments chronologically.
 *
 * Displays a list of Comment objects with author, timestamp, and body.
 * Exports `formatCommentDate` as a pure function for testability.
 */

import type { Comment } from "../lib/types";

// ---------------------------------------------------------------------------
// Pure helper — exported for tests
// ---------------------------------------------------------------------------

/** Formats an ISO date string into a human-readable relative/absolute label. */
export function formatCommentDate(isoDate: string): string {
  const date = new Date(isoDate);
  if (isNaN(date.getTime())) {
    return isoDate; // fallback: return raw string if parsing fails
  }

  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMinutes = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMinutes < 1) return "just now";
  if (diffMinutes < 60) return `${diffMinutes}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;

  // Absolute date for older comments
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface CommentListProps {
  comments: Comment[];
  /** Called when a new comment is submitted. */
  onAddComment?: (body: string) => Promise<void>;
  loading?: boolean;
}

export function CommentList({
  comments,
  onAddComment,
  loading = false,
}: CommentListProps) {
  function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = e.currentTarget;
    const textarea = form.elements.namedItem("body") as HTMLTextAreaElement;
    const body = textarea.value.trim();
    if (!body || !onAddComment) return;

    onAddComment(body).then(() => {
      textarea.value = "";
    });
  }

  return (
    <section aria-label="Comments">
      <h3 className="text-sm font-semibold text-gray-700 mb-3">
        Comments{" "}
        {comments.length > 0 && (
          <span className="ml-1 text-xs font-normal text-gray-400">
            ({comments.length})
          </span>
        )}
      </h3>

      {/* Comment thread */}
      {comments.length === 0 ? (
        <p className="text-sm text-gray-400 italic">No comments yet.</p>
      ) : (
        <ul className="space-y-4">
          {comments.map((comment) => (
            <li key={comment.id} className="flex gap-3">
              {/* Avatar */}
              <div className="shrink-0 w-7 h-7 rounded-full bg-gray-200 flex items-center justify-center text-xs font-medium text-gray-600 uppercase">
                {comment.author.charAt(0)}
              </div>

              {/* Body */}
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 mb-1">
                  <span className="text-xs font-medium text-gray-700">
                    {comment.author}
                  </span>
                  <span className="text-xs text-gray-400">
                    {formatCommentDate(comment.createdAt)}
                  </span>
                </div>
                <p className="text-sm text-gray-600 whitespace-pre-wrap break-words">
                  {comment.body}
                </p>
              </div>
            </li>
          ))}
        </ul>
      )}

      {/* Add comment form */}
      {onAddComment && (
        <form onSubmit={handleSubmit} className="mt-4">
          <textarea
            name="body"
            rows={3}
            placeholder="Leave a comment…"
            className="w-full rounded-md border border-gray-200 px-3 py-2 text-sm text-gray-700 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
            disabled={loading}
          />
          <div className="mt-2 flex justify-end">
            <button
              type="submit"
              disabled={loading}
              className="px-3 py-1.5 bg-blue-600 text-white text-xs font-medium rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
            >
              {loading ? "Posting…" : "Comment"}
            </button>
          </div>
        </form>
      )}
    </section>
  );
}
