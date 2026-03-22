/**
 * TelemetrySummary — displays telemetry metrics for a single item or
 * aggregate telemetry across all items (used on the Telemetry page).
 *
 * Exports pure helper functions for testability:
 *   - aggregateTelemetry(records): sums duration, tokens, cost
 *   - formatDuration(ms): "2m 30s"
 *   - formatTokens(n): "150K"
 */

import type { TelemetryRecord, TelemetryModel } from "../lib/types";

// ---------------------------------------------------------------------------
// Pure helpers — exported for tests
// ---------------------------------------------------------------------------

export interface TelemetryAggregate {
  totalDurationMs: number;
  totalTokens: number;
  totalCost: number;
  recordCount: number;
}

/** Computes aggregate totals from an array of telemetry records. */
export function aggregateTelemetry(records: TelemetryRecord[]): TelemetryAggregate {
  let totalDurationMs = 0;
  let totalTokens = 0;
  let totalCost = 0;

  for (const r of records) {
    totalDurationMs += r.duration_ms;
    totalTokens += r.tokens;
    totalCost += r.cost_estimate ?? 0;
  }

  return {
    totalDurationMs,
    totalTokens,
    totalCost,
    recordCount: records.length,
  };
}

/** Formats milliseconds as "Xm Ys" or "Xs" if under a minute. */
export function formatDuration(ms: number): string {
  const totalSeconds = Math.round(ms / 1000);
  if (totalSeconds < 60) return `${totalSeconds}s`;
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return seconds === 0 ? `${minutes}m` : `${minutes}m ${seconds}s`;
}

/** Formats token count as "150K" for large values, raw number for small. */
export function formatTokens(tokens: number): string {
  if (tokens >= 1000) {
    const k = Math.round(tokens / 1000);
    return `${k}K`;
  }
  return String(tokens);
}

/** Formats cost estimate as "$X.XX". */
export function formatCost(cost: number): string {
  return `$${cost.toFixed(2)}`;
}

// ---------------------------------------------------------------------------
// Model badge color
// ---------------------------------------------------------------------------

function modelColorClass(model: TelemetryModel | string): string {
  switch (model) {
    case "haiku":
      return "bg-teal-100 text-teal-700";
    case "sonnet":
      return "bg-indigo-100 text-indigo-700";
    case "opus":
      return "bg-orange-100 text-orange-700";
    case "mixed":
      return "bg-violet-100 text-violet-700";
    default:
      return "bg-gray-100 text-gray-700";
  }
}

// ---------------------------------------------------------------------------
// Metric card sub-component
// ---------------------------------------------------------------------------

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-lg border border-gray-200 p-4">
      <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">
        {label}
      </p>
      <p className="text-2xl font-semibold text-gray-900">{value}</p>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Telemetry record row
// ---------------------------------------------------------------------------

function TelemetryRow({ record }: { record: TelemetryRecord }) {
  return (
    <tr className="border-b border-gray-100 last:border-0 hover:bg-gray-50 transition-colors">
      <td className="py-3 pr-4 text-sm text-gray-600">
        #{record.item_id}
      </td>
      <td className="py-3 pr-4">
        <span
          className={[
            "inline-flex items-center px-2 py-0.5 rounded text-xs font-medium",
            modelColorClass(record.model),
          ].join(" ")}
        >
          {record.model}
        </span>
      </td>
      <td className="py-3 pr-4 text-sm text-gray-700 tabular-nums">
        {formatDuration(record.duration_ms)}
      </td>
      <td className="py-3 pr-4 text-sm text-gray-700 tabular-nums">
        {formatTokens(record.tokens)}
      </td>
      <td className="py-3 text-sm text-gray-700 tabular-nums">
        {record.cost_estimate !== null
          ? formatCost(record.cost_estimate)
          : "—"}
      </td>
    </tr>
  );
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------

interface TelemetrySummaryProps {
  records: TelemetryRecord[];
  /** If true, shows the full table of individual records in addition to aggregate cards. */
  showTable?: boolean;
  /** Title to show above the summary cards. */
  title?: string;
}

export function TelemetrySummary({
  records,
  showTable = false,
  title = "Telemetry",
}: TelemetrySummaryProps) {
  const aggregate = aggregateTelemetry(records);

  if (records.length === 0) {
    return (
      <section aria-label="Telemetry">
        {title && (
          <h3 className="text-sm font-semibold text-gray-700 mb-3">{title}</h3>
        )}
        <p className="text-sm text-gray-400 italic">No telemetry data.</p>
      </section>
    );
  }

  return (
    <section aria-label="Telemetry">
      {title && (
        <h3 className="text-sm font-semibold text-gray-700 mb-3">{title}</h3>
      )}

      {/* Aggregate metric cards */}
      <div className="grid grid-cols-3 gap-3 mb-6">
        <MetricCard
          label="Total Duration"
          value={formatDuration(aggregate.totalDurationMs)}
        />
        <MetricCard
          label="Total Tokens"
          value={formatTokens(aggregate.totalTokens)}
        />
        <MetricCard
          label="Est. Cost"
          value={
            aggregate.totalCost > 0
              ? formatCost(aggregate.totalCost)
              : "—"
          }
        />
      </div>

      {/* Record table */}
      {showTable && records.length > 0 && (
        <div className="overflow-x-auto rounded-lg border border-gray-200">
          <table className="w-full text-left">
            <thead className="bg-gray-50 border-b border-gray-200">
              <tr>
                <th className="py-2 pr-4 pl-3 text-xs font-semibold text-gray-500 uppercase tracking-wide">
                  Item
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
            <tbody className="pl-3">
              {records.map((r) => (
                <TelemetryRow key={r.id} record={r} />
              ))}
            </tbody>
          </table>
        </div>
      )}
    </section>
  );
}
