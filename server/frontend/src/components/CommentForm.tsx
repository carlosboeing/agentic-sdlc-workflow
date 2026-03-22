/**
 * CommentForm — form for creating a new comment or reply.
 *
 * Props:
 *   onSubmit   — called with (body, author) when the form is submitted
 *   onCancel   — called when the user cancels (optional)
 *   isReply    — if true, shows a more compact reply form
 *   autoFocus  — if true, focuses the textarea on mount
 *
 * The form validates that both body and author are non-empty before
 * allowing submission. Clears the form after successful submission.
 */

import { useState, useRef, useEffect } from "react";

interface CommentFormProps {
  onSubmit: (body: string, author: string) => Promise<void>;
  onCancel?: () => void;
  isReply?: boolean;
  autoFocus?: boolean;
}

export function CommentForm({
  onSubmit,
  onCancel,
  isReply = false,
  autoFocus = false,
}: CommentFormProps) {
  const [body, setBody] = useState("");
  const [author, setAuthor] = useState("human");
  const [submitting, setSubmitting] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    if (autoFocus && textareaRef.current) {
      textareaRef.current.focus();
    }
  }, [autoFocus]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!body.trim() || !author.trim()) return;

    setSubmitting(true);
    try {
      await onSubmit(body.trim(), author.trim());
      setBody("");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className={isReply ? "mt-2" : "mt-3"}>
      <textarea
        ref={textareaRef}
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder={isReply ? "Write a reply..." : "Write a comment..."}
        className="w-full rounded border border-gray-300 px-3 py-2 text-sm text-gray-700 placeholder-gray-400 focus:border-blue-400 focus:outline-none focus:ring-1 focus:ring-blue-400 resize-none"
        rows={isReply ? 2 : 3}
        disabled={submitting}
      />
      {!isReply && (
        <input
          type="text"
          value={author}
          onChange={(e) => setAuthor(e.target.value)}
          placeholder="Author"
          className="mt-1 w-full rounded border border-gray-300 px-3 py-1.5 text-xs text-gray-600 placeholder-gray-400 focus:border-blue-400 focus:outline-none focus:ring-1 focus:ring-blue-400"
          disabled={submitting}
        />
      )}
      <div className="mt-2 flex items-center gap-2">
        <button
          type="submit"
          disabled={submitting || !body.trim()}
          className="rounded bg-blue-600 px-3 py-1 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {submitting ? "Posting..." : isReply ? "Reply" : "Comment"}
        </button>
        {onCancel && (
          <button
            type="button"
            onClick={onCancel}
            className="rounded px-3 py-1 text-xs text-gray-500 hover:text-gray-700 hover:bg-gray-100"
            disabled={submitting}
          >
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}
