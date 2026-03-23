/**
 * MarkdownViewer — full-page markdown renderer with GFM + Mermaid support.
 *
 * Used by the DocumentViewer page to render markdown files from the docs/
 * directory. Extends the inline ItemBody component with:
 * - Mermaid diagram rendering (client-side, lazy-loaded)
 * - Larger heading styles suitable for full-page reading
 * - Stable anchor IDs on headings for paragraph-anchored comments
 * - Optional inline comment threading via AnchoredParagraph wrappers
 */

import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { useEffect, useRef, useMemo } from "react";
import { AnchoredParagraph } from "./AnchoredParagraph";
import { slugifyHeading } from "../lib/anchors";
import type { Comment } from "../lib/types";

interface MarkdownViewerProps {
  /** Raw markdown content to render. */
  content: string;
  /** Optional CSS class added to the outer article element. */
  className?: string;
  /** Comment data grouped by anchor ID. Enables inline comment threading when provided. */
  commentsByAnchor?: Map<string, Comment[]>;
  /** Currently active (open) anchor ID. */
  activeAnchor?: string | null;
  /** Called when the user toggles a comment thread on an anchor. */
  onToggleAnchor?: (anchor: string) => void;
}

/**
 * Extract text content from React children recursively.
 * Used to generate heading slugs from nested elements.
 */
function extractText(children: React.ReactNode): string {
  if (typeof children === "string") return children;
  if (typeof children === "number") return String(children);
  if (Array.isArray(children)) return children.map(extractText).join("");
  if (children && typeof children === "object" && "props" in (children as object)) {
    return extractText((children as React.ReactElement).props.children);
  }
  return "";
}

export function MarkdownViewer({
  content,
  className = "",
  commentsByAnchor,
  activeAnchor,
  onToggleAnchor,
}: MarkdownViewerProps) {
  const articleRef = useRef<HTMLElement>(null);
  // Paragraph counter — reset each render via useMemo.
  // We use an object ref so the counter can be mutated during render
  // without triggering re-renders. Reset on content change.
  const paragraphCounter = useMemo(() => ({ current: 0 }), [content]);

  const commentsEnabled = !!commentsByAnchor && !!onToggleAnchor;

  // Helper to wrap an element with AnchoredParagraph when comments are enabled
  function wrapWithAnchor(anchor: string, element: React.ReactNode) {
    if (!commentsEnabled) return element;
    const count = commentsByAnchor?.get(anchor)?.length ?? 0;
    return (
      <AnchoredParagraph
        anchor={anchor}
        commentCount={count}
        isActive={activeAnchor === anchor}
        onToggle={onToggleAnchor!}
      >
        {element}
      </AnchoredParagraph>
    );
  }

  // Render Mermaid diagrams after the component mounts or content changes.
  // Mermaid is loaded lazily to avoid bundling it into the critical path.
  // Security note: Mermaid renders diagrams from our own docs/ directory only.
  // The server validates all document paths to prevent traversal attacks, so
  // the content originates from trusted repo files, not from user input.
  useEffect(() => {
    const el = articleRef.current;
    if (!el) return;

    const mermaidBlocks = el.querySelectorAll("pre code.language-mermaid");
    if (mermaidBlocks.length === 0) return;

    import("mermaid")
      .then((m) => {
        const mermaid = m.default;
        mermaid.initialize({ startOnLoad: false, theme: "neutral" });

        mermaidBlocks.forEach((block, idx) => {
          const pre = block.parentElement;
          if (!pre) return;
          const definition = block.textContent ?? "";
          const svgId = `mermaid-diagram-${Date.now()}-${idx}`;

          const div = document.createElement("div");
          div.className = "mermaid-container my-4 overflow-x-auto rounded border border-gray-200 p-4 bg-white";
          pre.replaceWith(div);

          mermaid
            .render(svgId, definition)
            .then(({ svg }) => {
              // Mermaid SVG is from trusted repo docs (path-traversal-protected at API layer).
              // Using textContent would lose the SVG structure — this is the standard
              // Mermaid rendering pattern. The source content is not user-supplied.
              div.textContent = "";
              const template = document.createElement("template");
              template.innerHTML = svg;
              div.appendChild(template.content);
            })
            .catch(() => {
              const fallback = document.createElement("pre");
              fallback.className = "overflow-x-auto rounded-lg bg-gray-900 p-4 text-xs text-gray-100 font-mono";
              fallback.textContent = definition;
              div.replaceWith(fallback);
            });
        });
      })
      .catch(() => {
        // Mermaid not available — leave as code blocks
      });
  }, [content]);

  return (
    <article
      ref={articleRef}
      className={`prose prose-sm prose-gray max-w-none ${commentsEnabled ? "pl-8" : ""} ${className}`}
    >
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        components={{
          // Headings — add slug-based anchor IDs for paragraph anchoring
          h1({ children }) {
            const text = extractText(children);
            const id = slugifyHeading(text);
            const heading = (
              <h1
                id={id}
                className="text-2xl font-bold text-gray-900 mt-6 mb-3 pb-2 border-b border-gray-200"
              >
                {children}
              </h1>
            );
            return wrapWithAnchor(id, heading);
          },
          h2({ children }) {
            const text = extractText(children);
            const id = slugifyHeading(text);
            const heading = (
              <h2
                id={id}
                className="text-xl font-semibold text-gray-800 mt-5 mb-2"
              >
                {children}
              </h2>
            );
            return wrapWithAnchor(id, heading);
          },
          h3({ children }) {
            const text = extractText(children);
            const id = slugifyHeading(text);
            const heading = (
              <h3
                id={id}
                className="text-lg font-semibold text-gray-700 mt-4 mb-2"
              >
                {children}
              </h3>
            );
            return wrapWithAnchor(id, heading);
          },
          h4({ children }) {
            const text = extractText(children);
            const id = slugifyHeading(text);
            const heading = (
              <h4
                id={id}
                className="text-base font-semibold text-gray-700 mt-3 mb-1"
              >
                {children}
              </h4>
            );
            return wrapWithAnchor(id, heading);
          },
          // Code blocks — styled with dark background; Mermaid handled in useEffect
          code({ className: cls, children, ...props }) {
            const isInline = !cls;
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
                <code className={`${cls ?? ""} text-gray-100 font-mono`} {...props}>
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
              <input className="mr-1.5 accent-blue-600" {...props} readOnly />
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
          // Paragraphs — wrapped with AnchoredParagraph when comments are enabled
          p({ children }) {
            const anchor = `p-${paragraphCounter.current++}`;
            const paragraph = (
              <p className="text-gray-700 leading-relaxed my-2">{children}</p>
            );
            return wrapWithAnchor(anchor, paragraph);
          },
          // Horizontal rule
          hr() {
            return <hr className="my-6 border-gray-200" />;
          },
          // Lists
          ul({ children }) {
            return (
              <ul className="list-disc list-inside space-y-1 my-2 text-gray-700">
                {children}
              </ul>
            );
          },
          ol({ children }) {
            return (
              <ol className="list-decimal list-inside space-y-1 my-2 text-gray-700">
                {children}
              </ol>
            );
          },
        }}
      >
        {content}
      </ReactMarkdown>
    </article>
  );
}
