/**
 * AnchoredParagraph — wraps a paragraph or heading with a margin comment icon.
 *
 * On hover, displays a small comment icon in the left margin. Clicking the
 * icon opens the comment thread panel for that anchor. If comments already
 * exist for the anchor, a badge with the count is shown.
 */

interface AnchoredParagraphProps {
  /** The anchor ID for this element. */
  anchor: string;
  /** Number of existing comments at this anchor. */
  commentCount: number;
  /** Whether the thread panel is currently open for this anchor. */
  isActive: boolean;
  /** Called when the user clicks the margin icon. */
  onToggle: (anchor: string) => void;
  /** The wrapped content to render. */
  children: React.ReactNode;
}

export function AnchoredParagraph({
  anchor,
  commentCount,
  isActive,
  onToggle,
  children,
}: AnchoredParagraphProps) {
  return (
    <div
      className="group relative"
      data-anchor={anchor}
    >
      {/* Margin icon — visible on hover or when comments exist */}
      <button
        onClick={() => onToggle(anchor)}
        className={`
          absolute -left-8 top-1 flex items-center gap-0.5
          rounded px-1 py-0.5 text-xs transition-opacity
          ${isActive
            ? "opacity-100 bg-blue-100 text-blue-600"
            : commentCount > 0
              ? "opacity-70 text-blue-500 hover:opacity-100"
              : "opacity-0 group-hover:opacity-60 text-gray-400 hover:text-blue-500 hover:opacity-100"
          }
        `}
        aria-label={`${commentCount > 0 ? `${commentCount} comments` : "Add comment"} on ${anchor}`}
        title={commentCount > 0 ? `${commentCount} comment${commentCount !== 1 ? "s" : ""}` : "Add comment"}
      >
        {/* Comment icon (speech bubble) */}
        <svg
          className="w-3.5 h-3.5"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          strokeWidth={2}
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
          />
        </svg>
        {commentCount > 0 && (
          <span className="font-medium">{commentCount}</span>
        )}
      </button>

      {/* Content */}
      {children}
    </div>
  );
}
