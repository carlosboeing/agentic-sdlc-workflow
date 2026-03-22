/**
 * Document Viewer page — markdown preview with file tree sidebar.
 *
 * Layout:
 *   ┌─────────────────────────────────────────────────┐
 *   │  [Sidebar]                 [Content area]        │
 *   │  DocumentTree              MarkdownViewer         │
 *   │  (scrollable file list)    (scrollable content)  │
 *   └─────────────────────────────────────────────────┘
 *
 * State:
 * - File list loaded on mount via GET /api/documents
 * - Selected file loaded on click via GET /api/documents/:path
 * - URL param (/* wildcard) pre-selects a file on direct navigation
 *
 * Implemented in E06-S01.
 */

import { useState, useEffect, useRef } from "react";
import { useParams, useNavigate } from "react-router-dom";
import { DocumentTree } from "../components/DocumentTree";
import { MarkdownViewer } from "../components/MarkdownViewer";
import { useDocument } from "../hooks/useDocument";
import { api } from "../lib/api";
import type { DocumentEntry } from "../lib/types";

export function DocumentViewer() {
  // The /* route in App.tsx gives us the splat param
  const { "*": urlPath } = useParams<{ "*": string }>();
  const navigate = useNavigate();

  // File tree state
  const [files, setFiles] = useState<DocumentEntry[]>([]);
  const [filesLoading, setFilesLoading] = useState(true);
  const [filesError, setFilesError] = useState<string | null>(null);

  // Current document state
  const [selectedPath, setSelectedPath] = useState<string | null>(
    urlPath ?? null
  );

  // useDocument handles fetching, loading state, error state, and request
  // cancellation whenever selectedPath changes.
  const { document, loading: docLoading, error: docError } = useDocument(selectedPath);

  // Scroll position memory: path → scrollTop
  const scrollPositions = useRef<Map<string, number>>(new Map());
  const contentRef = useRef<HTMLDivElement>(null);

  // Load the file tree on mount
  useEffect(() => {
    let cancelled = false;
    api
      .listDocuments()
      .then((entries) => {
        if (!cancelled) {
          setFiles(entries);
          setFilesLoading(false);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          const msg = err instanceof Error ? err.message : "Failed to load documents";
          setFilesError(msg);
          setFilesLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, []);

  // Sync URL param changes (e.g., browser back/forward) to selected path
  useEffect(() => {
    if (urlPath !== undefined) {
      setSelectedPath(urlPath || null);
    }
  }, [urlPath]);

  // Restore scroll position after a document loads successfully
  useEffect(() => {
    if (!document || !selectedPath) return;
    requestAnimationFrame(() => {
      if (contentRef.current) {
        const saved = scrollPositions.current.get(selectedPath) ?? 0;
        contentRef.current.scrollTop = saved;
      }
    });
  }, [document, selectedPath]);

  // Save scroll position when navigating away
  function handleSelectPath(path: string) {
    // Save current scroll position
    if (selectedPath && contentRef.current) {
      scrollPositions.current.set(selectedPath, contentRef.current.scrollTop);
    }
    setSelectedPath(path);
    // Update URL to reflect selection
    navigate(`/docs/${path}`, { replace: true });
  }

  return (
    <div className="flex h-full">
      {/* Sidebar — file tree */}
      <aside className="w-64 flex-shrink-0 border-r border-gray-200 bg-gray-50 overflow-y-auto p-3">
        <h2 className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3 px-2">
          Documents
        </h2>
        {filesLoading ? (
          <p className="text-sm text-gray-400 italic px-2">Loading…</p>
        ) : filesError ? (
          <p className="text-sm text-red-500 px-2">{filesError}</p>
        ) : (
          <DocumentTree
            files={files}
            selectedPath={selectedPath}
            onSelectPath={handleSelectPath}
          />
        )}
      </aside>

      {/* Content area */}
      <div ref={contentRef} className="flex-1 overflow-y-auto p-6">
        {!selectedPath ? (
          <div className="flex flex-col items-center justify-center h-full text-gray-400">
            <svg
              className="w-12 h-12 mb-3 opacity-40"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={1.5}
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            <p className="text-sm">Select a document from the sidebar</p>
          </div>
        ) : docLoading ? (
          <div className="flex items-center justify-center h-32">
            <p className="text-sm text-gray-400">Loading…</p>
          </div>
        ) : docError ? (
          <div className="rounded-lg border border-red-200 bg-red-50 p-4">
            <p className="text-sm text-red-600">{docError}</p>
          </div>
        ) : document ? (
          <>
            {/* Document header */}
            <div className="mb-4 pb-3 border-b border-gray-100">
              <p className="text-xs text-gray-400 font-mono">{document.path}</p>
            </div>
            {/* Markdown content */}
            <MarkdownViewer content={document.content} />
          </>
        ) : null}
      </div>
    </div>
  );
}
