/**
 * Item Detail page — shows full work item details.
 *
 * Displays:
 *   - Title, type, status badge, labels (ItemHeader)
 *   - Body rendered as markdown (ItemBody)
 *   - Hierarchy: parent link + children list (ItemHierarchy)
 *   - Comments with add-comment form (ItemComments)
 *   - Telemetry data: model, duration, tokens, cost (TelemetrySummary)
 *
 * Data is fetched via useItem which parallelises all secondary requests.
 * Navigating back to / (board) preserves the board state since the SPA
 * uses client-side routing with no page reload.
 */

import { useParams, Link } from "react-router-dom";
import { useItem } from "../hooks/useItem";
import { ItemHeader } from "../components/ItemHeader";
import { ItemBody } from "../components/ItemBody";
import { ItemHierarchy } from "../components/ItemHierarchy";
import { ItemComments } from "../components/ItemComments";
import { TelemetrySummary } from "../components/TelemetrySummary";

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

function LoadingSkeleton() {
  return (
    <div className="animate-pulse space-y-4 p-6">
      <div className="h-4 w-1/4 bg-gray-200 rounded" />
      <div className="h-6 w-3/4 bg-gray-200 rounded" />
      <div className="h-3 w-1/2 bg-gray-200 rounded" />
      <div className="h-32 w-full bg-gray-200 rounded mt-6" />
    </div>
  );
}

// ---------------------------------------------------------------------------
// Page component
// ---------------------------------------------------------------------------

export function ItemDetail() {
  const { id } = useParams<{ id: string }>();
  const { data, loading, error } = useItem(id);

  // Loading state
  if (loading) {
    return <LoadingSkeleton />;
  }

  // Error state
  if (error || !data) {
    return (
      <div className="p-6">
        <Link
          to="/"
          className="inline-flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 mb-4 transition-colors"
        >
          ← Back to Board
        </Link>
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-red-700 mb-1">
            Failed to load item
          </h2>
          <p className="text-sm text-red-600">{error ?? "Unknown error"}</p>
        </div>
      </div>
    );
  }

  const { item, parent, children, comments, telemetry } = data;

  return (
    <div className="max-w-4xl mx-auto p-6 space-y-8">
      {/* Back to board link */}
      <Link
        to="/"
        className="inline-flex items-center gap-1 text-xs text-gray-400 hover:text-gray-600 transition-colors"
      >
        ← Back to Board
      </Link>

      {/* Item header: type, status, title, labels */}
      <ItemHeader item={item} />

      {/* Two-column layout: body (wide) + sidebar (narrow) */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Main column: body + comments */}
        <div className="lg:col-span-2 space-y-8">
          {/* Markdown body */}
          <section aria-label="Description">
            <h2 className="text-sm font-semibold text-gray-700 mb-3">
              Description
            </h2>
            <ItemBody body={item.body} />
          </section>

          {/* Comments */}
          <ItemComments itemId={item.id} initialComments={comments} />
        </div>

        {/* Sidebar: hierarchy + telemetry + metadata */}
        <div className="space-y-6">
          {/* Hierarchy */}
          <ItemHierarchy
            item={item}
            parent={parent}
            children={children}
          />

          {/* Telemetry */}
          {telemetry.length > 0 && (
            <TelemetrySummary records={telemetry} title="Telemetry" />
          )}

          {/* Metadata */}
          <section aria-label="Metadata">
            <h3 className="text-sm font-semibold text-gray-700 mb-3">
              Details
            </h3>
            <dl className="space-y-2 text-sm">
              {item.createdBy && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">Created by</dt>
                  <dd className="text-gray-700 font-medium">
                    {item.createdBy}
                  </dd>
                </div>
              )}
              {item.externalId && (
                <div className="flex justify-between">
                  <dt className="text-gray-500">GitHub Issue</dt>
                  <dd className="text-gray-700">
                    {item.externalUrl ? (
                      <a
                        href={item.externalUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-600 hover:text-blue-700 underline"
                      >
                        #{item.externalId}
                      </a>
                    ) : (
                      `#${item.externalId}`
                    )}
                  </dd>
                </div>
              )}
              <div className="flex justify-between">
                <dt className="text-gray-500">Created</dt>
                <dd className="text-gray-700">
                  {new Date(item.createdAt).toLocaleDateString("en-US", {
                    year: "numeric",
                    month: "short",
                    day: "numeric",
                  })}
                </dd>
              </div>
              <div className="flex justify-between">
                <dt className="text-gray-500">Updated</dt>
                <dd className="text-gray-700">
                  {new Date(item.updatedAt).toLocaleDateString("en-US", {
                    year: "numeric",
                    month: "short",
                    day: "numeric",
                  })}
                </dd>
              </div>
            </dl>
          </section>
        </div>
      </div>
    </div>
  );
}
