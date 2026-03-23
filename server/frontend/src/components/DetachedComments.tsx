/**
 * DetachedComments — section for orphaned comments whose anchors
 * no longer exist in the document.
 *
 * When a heading is renamed or a paragraph is removed, comments
 * that were anchored to it become "detached". They are still
 * valuable and should not be hidden, so they appear in a separate
 * section at the bottom of the document.
 */

import type { Comment } from "../lib/types";

interface DetachedCommentsProps {
  /** Comments whose anchors are no longer in the document. */
  comments: Comment[];
}

export function DetachedComments({ comments }: DetachedCommentsProps) {
  if (comments.length === 0) return null;

  // Group by original anchor for readability
  const byAnchor = new Map<string, Comment[]>();
  for (const comment of comments) {
    const anchor = comment.anchor ?? "(no anchor)";
    const existing = byAnchor.get(anchor) ?? [];
    existing.push(comment);
    byAnchor.set(anchor, existing);
  }

  return (
    <div className="mt-8 rounded-lg border border-amber-200 bg-amber-50 p-4">
      <div className="flex items-center gap-2 mb-3">
        <svg
          className="w-4 h-4 text-amber-500"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4.5c-.77-.833-2.694-.833-3.464 0L3.34 16.5c-.77.833.192 2.5 1.732 2.5z"
          />
        </svg>
        <h3 className="text-sm font-semibold text-amber-700">
          Detached Comments
        </h3>
        <span className="text-xs text-amber-500">
          ({comments.length} comment{comments.length !== 1 ? "s" : ""} on removed/renamed sections)
        </span>
      </div>

      <div className="space-y-3">
        {Array.from(byAnchor.entries()).map(([anchor, anchorComments]) => (
          <div key={anchor} className="border-l-2 border-amber-300 pl-3">
            <p className="text-xs font-mono text-amber-600 mb-1">
              Anchor: {anchor}
            </p>
            {anchorComments.map((comment) => (
              <div key={comment.id} className="py-1">
                <div className="flex items-center gap-2 text-xs">
                  <span className="font-medium text-gray-600">
                    {comment.author}
                  </span>
                  <span className="text-gray-400">
                    {new Date(comment.createdAt).toLocaleDateString()}
                  </span>
                </div>
                <p className="text-sm text-gray-600 mt-0.5">{comment.body}</p>
              </div>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
