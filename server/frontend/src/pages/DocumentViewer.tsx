/**
 * Document Viewer page — markdown preview with inline comments.
 *
 * Placeholder for E06-S01 (Document API Routes and Markdown Viewer).
 * Will render markdown files from docs/ with paragraph-anchored comment threads.
 */

import { useParams } from "react-router-dom";

export function DocumentViewer() {
  const { "*": docPath } = useParams<{ "*": string }>();

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-gray-900 mb-2">
        Document Viewer
      </h1>
      {docPath && (
        <p className="text-sm text-gray-400 mb-4 font-mono">{docPath}</p>
      )}
      <p className="text-gray-500">
        Document viewer — coming in E06-S01. This page will render markdown
        files from the docs/ directory with full GFM support, Mermaid diagrams,
        and paragraph-anchored comment threads.
      </p>
    </div>
  );
}
