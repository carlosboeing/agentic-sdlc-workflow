#!/usr/bin/env bash
set -euo pipefail

# setup-labels.sh — Create GitHub labels for NeuralNorris SDLC workflow.
# Idempotent: skips labels that already exist.
# Usage: ./scripts/setup-labels.sh

REPO="carlosboeing/agentic-sdlc-workflow"

create_label() {
  local name="$1" color="$2" description="$3"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$description" --force 2>/dev/null \
    && echo "  ok: $name" \
    || echo "  failed: $name"
}

echo "Setting up labels for $REPO..."

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
