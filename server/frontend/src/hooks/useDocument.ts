/**
 * useDocument hook — fetches a document from GET /api/documents/:path.
 *
 * Returns:
 *   document  — the fetched DocumentContent (null while loading or on error)
 *   loading   — true while the request is in flight
 *   error     — error message string, or null on success
 *
 * The hook re-fetches whenever `path` changes. An empty or null path
 * means no document is selected — returns immediately with null state.
 */

import { useState, useEffect } from "react";
import { api } from "../lib/api";
import type { DocumentContent } from "../lib/types";

interface UseDocumentResult {
  document: DocumentContent | null;
  loading: boolean;
  error: string | null;
}

export function useDocument(path: string | null): UseDocumentResult {
  const [document, setDocument] = useState<DocumentContent | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!path) {
      setDocument(null);
      setLoading(false);
      setError(null);
      return;
    }

    let cancelled = false;
    setLoading(true);
    setError(null);

    api
      .getDocument(path)
      .then((doc) => {
        if (!cancelled) {
          setDocument(doc);
          setLoading(false);
        }
      })
      .catch((err: unknown) => {
        if (!cancelled) {
          const msg =
            err instanceof Error ? err.message : "Failed to load document";
          setError(msg);
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [path]);

  return { document, loading, error };
}
