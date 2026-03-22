/**
 * Telemetry page — aggregate cost, token usage, and duration summary
 * across all items.
 *
 * Fetches all items (hierarchy/story filter), then fetches telemetry for each.
 * Aggregates totals and shows a summary + per-item breakdown table.
 */

import { useState, useEffect } from "react";
import { Link } from "react-router-dom";
import { api } from "../lib/api";
import type { TelemetryRecord, WorkItem } from "../lib/types";
import {
  TelemetrySummary,
  aggregateTelemetry,
  formatDuration,
  formatTokens,
  formatCost,
} from "../components/TelemetrySummary";

// ---------------------------------------------------------------------------
// Telemetry page state
// ---------------------------------------------------------------------------

interface TelemetryPageState {
  records: TelemetryRecord[];
  loading: boolean;
  error: string | null;
}

// ---------------------------------------------------------------------------
// Per-item row in the breakdown table
// ---------------------------------------------------------------------------

interface ItemTelemetryRow {
  item: WorkItem;
  records: TelemetryRecord[];
}

function BreakdownRow({ item, records }: ItemTelemetryRow) {
  const aggregate = aggregateTelemetry(records);
  const latestModel = records[records.length - 1]?.model ?? "—";

  return (
    <tr className="border-b border-gray-100 last:border-0 hover:bg-gray-50 transition-colors">
      <td className="py-3 pl-3 pr-4">
        <Link
          to={`/items/${item.id}`}
          className="text-blue-600 hover:text-blue-700 text-sm font-medium"
        >
          #{item.id}
        </Link>
      </td>
      <td className="py-3 pr-4 text-sm text-gray-700 max-w-xs truncate">
        <Link
          to={`/items/${item.id}`}
          className="hover:text-blue-600 transition-colors"
        >
          {item.title}
        </Link>
      </td>
      <td className="py-3 pr-4">
        <span className="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-600">
          {item.type}
        </span>
      </td>
      <td className="py-3 pr-4 text-sm text-gray-600">
        {latestModel}
      </td>
      <td className="py-3 pr-4 text-sm text-gray-700 tabular-nums">
        {formatDuration(aggregate.totalDurationMs)}
      </td>
      <td className="py-3 pr-4 text-sm text-gray-700 tabular-nums">
        {formatTokens(aggregate.totalTokens)}
      </td>
      <td className="py-3 text-sm text-gray-700 tabular-nums">
        {aggregate.totalCost > 0 ? formatCost(aggregate.totalCost) : "—"}
      </td>
    </tr>
  );
}

// ---------------------------------------------------------------------------
// Main page component
// ---------------------------------------------------------------------------

export function Telemetry() {
  const [state, setState] = useState<TelemetryPageState>({
    records: [],
    loading: true,
    error: null,
  });

  const [itemsWithTelemetry, setItemsWithTelemetry] = useState<
    ItemTelemetryRow[]
  >([]);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setState({ records: [], loading: true, error: null });

      try {
        // Fetch all items that might have telemetry (all types, all statuses)
        const items = await api.listItems({ limit: 500 });

        // Fetch telemetry for each item in parallel
        const telemetryResults = await Promise.all(
          items.map((item) =>
            api
              .getItemTelemetry(item.id)
              .then((records) => ({ item, records }))
              .catch(() => ({ item, records: [] as TelemetryRecord[] }))
          )
        );

        // Filter to only items that have telemetry
        const withTelemetry = telemetryResults.filter(
          (r) => r.records.length > 0
        );

        // Flatten all records for aggregate summary
        const allRecords = withTelemetry.flatMap((r) => r.records);

        if (!cancelled) {
          setState({ records: allRecords, loading: false, error: null });
          setItemsWithTelemetry(withTelemetry);
        }
      } catch (err) {
        if (!cancelled) {
          setState({
            records: [],
            loading: false,
            error:
              err instanceof Error ? err.message : "Failed to load telemetry",
          });
        }
      }
    }

    void load();

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="max-w-5xl mx-auto p-6 space-y-8">
      {/* Page title */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900 mb-1">
          Costs &amp; Telemetry
        </h1>
        <p className="text-sm text-gray-500">
          Aggregate cost, token usage, and duration across all workflow items.
        </p>
      </div>

      {/* Loading state */}
      {state.loading && (
        <div className="animate-pulse space-y-3">
          <div className="grid grid-cols-3 gap-3">
            {[0, 1, 2].map((i) => (
              <div key={i} className="h-20 bg-gray-200 rounded-lg" />
            ))}
          </div>
          <div className="h-64 bg-gray-200 rounded-lg" />
        </div>
      )}

      {/* Error state */}
      {state.error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <h2 className="text-sm font-semibold text-red-700 mb-1">
            Failed to load telemetry
          </h2>
          <p className="text-sm text-red-600">{state.error}</p>
        </div>
      )}

      {/* Content */}
      {!state.loading && !state.error && (
        <>
          {/* Aggregate summary cards */}
          <TelemetrySummary
            records={state.records}
            title="Summary"
          />

          {/* Per-item breakdown table */}
          {itemsWithTelemetry.length > 0 ? (
            <section aria-label="Per-item telemetry breakdown">
              <h2 className="text-base font-semibold text-gray-800 mb-3">
                Breakdown by Item
              </h2>
              <div className="overflow-x-auto rounded-lg border border-gray-200">
                <table className="w-full text-left">
                  <thead className="bg-gray-50 border-b border-gray-200">
                    <tr>
                      <th className="py-2 pl-3 pr-4 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        ID
                      </th>
                      <th className="py-2 pr-4 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        Title
                      </th>
                      <th className="py-2 pr-4 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        Type
                      </th>
                      <th className="py-2 pr-4 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        Model
                      </th>
                      <th className="py-2 pr-4 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        Duration
                      </th>
                      <th className="py-2 pr-4 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        Tokens
                      </th>
                      <th className="py-2 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                        Cost
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {itemsWithTelemetry.map(({ item, records }) => (
                      <BreakdownRow
                        key={item.id}
                        item={item}
                        records={records}
                      />
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          ) : (
            <p className="text-sm text-gray-400 italic">
              No telemetry data has been recorded yet. Telemetry is posted by
              the orchestrator after each story completes.
            </p>
          )}
        </>
      )}
    </div>
  );
}
