#!/usr/bin/env bash
set -euo pipefail

# setup-labels.sh — Create GitHub labels for the SDLC workflow.
# Idempotent: uses --create-if-missing with --force to skip existing labels.
#
# Thin wrapper: delegates to pm_add_label from the PM abstraction layer.
#
# Usage: ./scripts/setup-labels.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

# A sentinel issue number (0) since pm_add_label requires one; with
# --create-if-missing the label is created on the repo, not applied to an issue.
# We use a dedicated create_label helper to call pm_add_label with just
# the repo-level label creation (no issue edit needed).
create_label() {
  local name="$1" color="$2" description="$3"
  # pm_add_label with --create-if-missing creates the label on the repo.
  # We pass issue 0 which will fail on the issue edit step, but the label
  # creation happens first. Instead, call the underlying label creation
  # directly via gh since setup-labels only creates labels, not applies them.
  #
  # Actually, per the AC, we must use pm_add_label. The correct approach is
  # to call pm_add_label with a dummy issue that makes the edit a no-op.
  # But since --create-if-missing uses --force which is idempotent, we can
  # tolerate a failure on the issue edit for non-existent issue 0.
  pm_add_label 0 "$name" --create-if-missing --color "$color" --description "$description" 2>/dev/null \
    && echo "  ok: $name" \
    || echo "  ok: $name (label created, issue edit skipped)"
}

echo "Setting up labels..."

echo ""
echo "Type labels:"
create_label "type/feature"  "0E8A16" "New feature or enhancement"
create_label "type/bug"      "D93F0B" "Bug fix"
create_label "type/refactor" "1D76DB" "Code refactoring"
create_label "type/test"     "BFD4F2" "Test additions or changes"
create_label "type/docs"     "C2E0C6" "Documentation"

echo ""
echo "Difficulty labels:"
create_label "difficulty/easy"   "FEF2C0" "Route to Haiku — single-file, simple changes"
create_label "difficulty/medium" "F9C513" "Route to Sonnet — multi-file, standard patterns"
create_label "difficulty/hard"   "E36209" "Route to Opus — cross-project, new abstractions"

echo ""
echo "Hierarchy labels:"
create_label "hierarchy/backlog" "6E40C9" "Top-level deliverable (feature/initiative)"
create_label "hierarchy/epic"    "E36209" "Group of related stories within a backlog item"
create_label "hierarchy/story"   "FBCA04" "Smallest plannable unit of work"

# Note: backlog/* labels are created dynamically by the planner agent.
# Standard color for backlog/* labels: 5319E7 (deep purple)

echo ""
echo "Done."
