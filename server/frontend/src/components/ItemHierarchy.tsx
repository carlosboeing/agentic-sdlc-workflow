/**
 * ItemHierarchy — displays parent link and children list for a work item.
 *
 * Shows:
 * - Parent item link (if parentId exists)
 * - List of child items with their status and type
 */

import { Link } from "react-router-dom";
import type { WorkItem } from "../lib/types";
import { StatusBadge } from "./StatusBadge";

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

interface ItemHierarchyProps {
  item: WorkItem;
  parent: WorkItem | null;
  children: WorkItem[];
  loading?: boolean;
}

export function ItemHierarchy({
  item,
  parent,
  children,
  loading = false,
}: ItemHierarchyProps) {
  const hasHierarchy = parent !== null || children.length > 0;

  if (loading) {
    return (
      <section aria-label="Hierarchy">
        <h3 className="text-sm font-semibold text-gray-700 mb-3">Hierarchy</h3>
        <p className="text-sm text-gray-400">Loading…</p>
      </section>
    );
  }

  if (!hasHierarchy) {
    return null;
  }

  return (
    <section aria-label="Hierarchy">
      <h3 className="text-sm font-semibold text-gray-700 mb-3">Hierarchy</h3>

      {/* Parent link */}
      {parent && (
        <div className="mb-3">
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">
            Parent
          </p>
          <Link
            to={`/items/${parent.id}`}
            className="inline-flex items-center gap-2 text-sm text-blue-600 hover:text-blue-700 transition-colors"
          >
            <span className="text-gray-400">↑</span>
            <span>{parent.title}</span>
            <StatusBadge status={parent.status} />
          </Link>
        </div>
      )}

      {/* Children list */}
      {children.length > 0 && (
        <div>
          <p className="text-xs text-gray-400 uppercase tracking-wide mb-2">
            Sub-items ({children.length})
          </p>
          <ul className="space-y-1.5">
            {children.map((child) => (
              <li key={child.id}>
                <Link
                  to={`/items/${child.id}`}
                  className="flex items-center gap-2 p-2 rounded-md hover:bg-gray-50 transition-colors group"
                >
                  <span className="text-gray-300 group-hover:text-gray-400 text-sm">
                    →
                  </span>
                  <span className="flex-1 text-sm text-gray-700 truncate">
                    {child.title}
                  </span>
                  <StatusBadge status={child.status} />
                </Link>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Current item indicator */}
      <p className="mt-2 text-xs text-gray-400">
        Viewing: <span className="font-medium text-gray-600">#{item.id}</span>
      </p>
    </section>
  );
}
