/**
 * ItemBody — renders work item body text as GitHub Flavored Markdown.
 *
 * Uses react-markdown + remark-gfm for full GFM support:
 * tables, code blocks, checkboxes, strikethrough, task lists.
 */

import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

interface ItemBodyProps {
  /** Markdown content to render. */
  body: string | null;
}

export function ItemBody({ body }: ItemBodyProps) {
  if (!body) {
    return (
      <p className="text-sm text-gray-400 italic">No description provided.</p>
    );
  }

  return (
    <article className="prose prose-sm prose-gray max-w-none">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          // Code blocks — styled with a dark background
          code({ className, children, ...props }) {
            const isInline = !className;
            if (isInline) {
              return (
                <code
                  className="px-1 py-0.5 rounded bg-gray-100 text-gray-800 text-xs font-mono"
                  {...props}
                >
                  {children}
                </code>
              );
            }
            return (
              <pre className="overflow-x-auto rounded-lg bg-gray-900 p-4 text-xs">
                <code className="text-gray-100 font-mono" {...props}>
                  {children}
                </code>
              </pre>
            );
          },
          // Tables — full-width with borders
          table({ children }) {
            return (
              <div className="overflow-x-auto my-4">
                <table className="w-full text-sm border-collapse border border-gray-200">
                  {children}
                </table>
              </div>
            );
          },
          th({ children }) {
            return (
              <th className="border border-gray-200 bg-gray-50 px-3 py-2 text-left text-xs font-semibold text-gray-600 uppercase tracking-wide">
                {children}
              </th>
            );
          },
          td({ children }) {
            return (
              <td className="border border-gray-200 px-3 py-2 text-sm text-gray-700">
                {children}
              </td>
            );
          },
          // Task list checkboxes
          input({ ...props }) {
            return (
              <input
                className="mr-1.5 accent-blue-600"
                {...props}
                readOnly
              />
            );
          },
          // Links — open external in new tab
          a({ href, children }) {
            const isExternal = href?.startsWith("http");
            return (
              <a
                href={href}
                className="text-blue-600 hover:text-blue-700 underline"
                {...(isExternal
                  ? { target: "_blank", rel: "noopener noreferrer" }
                  : {})}
              >
                {children}
              </a>
            );
          },
          // Blockquote
          blockquote({ children }) {
            return (
              <blockquote className="border-l-4 border-gray-300 pl-4 text-gray-500 italic my-3">
                {children}
              </blockquote>
            );
          },
        }}
      >
        {body}
      </ReactMarkdown>
    </article>
  );
}
