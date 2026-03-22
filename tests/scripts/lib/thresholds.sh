#!/usr/bin/env bash
# thresholds.sh — Standardized line-count thresholds for test assertions.
#
# Tiers:
#   THIN_WRAPPER     (30)  — Scripts that parse args and delegate to one adapter function
#                            (item-set-status.sh, item-close.sh, batch-set-status.sh, etc.)
#   SMALL_MODULE    (100)  — Single-function adapter files with limited scope
#                            (hierarchy.sh, labels.sh, comments.sh, lifecycle.sh, cost-budget.sh)
#   ADAPTER_MODULE  (250)  — Multi-function adapter files, one concern per file
#                            (items.sh, board.sh, reconcile.sh)
#   ORCHESTRATION   (200)  — Multi-step coordination scripts
#                            (item-create.sh, setup-labels.sh)
#   LARGE_ORCH      (500)  — Complex coordinators with templates and rendering
#                            (item-telemetry.sh)
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib/thresholds.sh"
#   # then use $THRESHOLD_ADAPTER_MODULE instead of a hardcoded number

THRESHOLD_THIN_WRAPPER=30
THRESHOLD_SMALL_MODULE=100
THRESHOLD_ADAPTER_MODULE=250
THRESHOLD_ORCHESTRATION=200
THRESHOLD_LARGE_ORCH=500
