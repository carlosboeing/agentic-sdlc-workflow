# GitHub Issue Categorization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `hierarchy/*` labels for board-level issue categorization, retire `epic/*` and GitHub default labels, standardize `backlog/*` colors, and update all workflow documentation.

**Architecture:** Pure workflow/docs change — no application code. Three static `hierarchy/*` labels enable board filtering by issue level. Per-epic `epic/*` labels are replaced by the combination of `backlog/*` grouping labels + `hierarchy/*` level labels + sub-issue parent-child linkage. All agent files, CLAUDE.md, and helper scripts are updated to reference the new label conventions.

**Tech Stack:** GitHub CLI (`gh`), Bash scripts, Markdown docs

---

## Task 1: Create Hierarchy Labels

**Files:**
- Modify: `scripts/setup-labels.sh`

**Step 1: Add hierarchy labels to `setup-labels.sh`**

Add a new section after the difficulty labels block (after line 34):

```bash
echo ""
echo "Hierarchy labels:"
create_label "hierarchy/backlog" "6E40C9" "Top-level deliverable (feature/initiative)"
create_label "hierarchy/epic"    "E36209" "Group of related stories within a backlog item"
create_label "hierarchy/story"   "FBCA04" "Smallest plannable unit of work"
```

**Step 2: Run the script to create the labels**

Run: `./scripts/setup-labels.sh`
Expected: Three new labels created (hierarchy/backlog, hierarchy/epic, hierarchy/story), existing labels show "exists".

**Step 3: Verify labels exist on GitHub**

Run: `gh label list --json name,color | jq '.[] | select(.name | startswith("hierarchy/"))'`
Expected: Three labels with correct colors (`6E40C9`, `E36209`, `FBCA04`).

**Step 4: Commit**

```bash
git add scripts/setup-labels.sh
git commit -m "chore(labels): add hierarchy/backlog, hierarchy/epic, hierarchy/story labels"
```

---

## Task 2: Apply Hierarchy Labels to Existing Issues

**Files:** None (GitHub API only)

This task applies the correct `hierarchy/*` label to every existing issue based on its role. The classification rules are:

- **hierarchy/backlog**: Issues that are top-level backlog items (parents of epics). These have no `epic/*` label, no `difficulty/*` label, and are either: (a) issues with `backlog/*` label that have no `epic/*` label (e.g., #122, #89, #106), or (b) old issues with no labels that are clearly backlog items (e.g., #1-#22, #122-#127).
- **hierarchy/epic**: Issues with an `epic/*` label but no `difficulty/*` label (e.g., #132 `[#122/E01]`, #94 `[#89/E01]`).
- **hierarchy/story**: Issues with both an `epic/*` label and a `difficulty/*` label (e.g., #135 `[#122/E01-S01]`).

**Step 1: Write a migration script**

Create `scripts/migrate-hierarchy-labels.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="carlosboeing/agentic-sdlc-workflow"

echo "Applying hierarchy labels to existing issues..."

# Get all issues with their labels
ISSUES=$(gh issue list --state all --limit 200 --repo "$REPO" \
  --json number,title,labels \
  | jq -c '.[]')

while IFS= read -r issue; do
  NUMBER=$(echo "$issue" | jq -r '.number')
  TITLE=$(echo "$issue" | jq -r '.title')
  LABELS=$(echo "$issue" | jq -r '[.labels[].name] | join(",")')

  HAS_EPIC=$(echo "$LABELS" | grep -c "epic/" || true)
  HAS_DIFFICULTY=$(echo "$LABELS" | grep -c "difficulty/" || true)
  HAS_BACKLOG=$(echo "$LABELS" | grep -c "backlog/" || true)
  HAS_HIERARCHY=$(echo "$LABELS" | grep -c "hierarchy/" || true)

  # Skip if already has a hierarchy label
  if [ "$HAS_HIERARCHY" -gt 0 ]; then
    echo "  skip #$NUMBER (already has hierarchy label)"
    continue
  fi

  if [ "$HAS_EPIC" -gt 0 ] && [ "$HAS_DIFFICULTY" -gt 0 ]; then
    # Has epic + difficulty = story
    echo "  story: #$NUMBER $TITLE"
    gh issue edit "$NUMBER" --repo "$REPO" --add-label "hierarchy/story"
  elif [ "$HAS_EPIC" -gt 0 ]; then
    # Has epic but no difficulty = epic
    echo "  epic:  #$NUMBER $TITLE"
    gh issue edit "$NUMBER" --repo "$REPO" --add-label "hierarchy/epic"
  elif [ "$HAS_BACKLOG" -gt 0 ]; then
    # Has backlog but no epic = could be backlog item OR a docs/plan issue
    # Check title for backlog indicators
    if echo "$TITLE" | grep -qiE "^\[Backlog\]|^SDLC Self-Orchestration|^Test SDLC|^Agentic SDLC|Mythical Creatures Field Guide|Intergalactic Travel"; then
      echo "  backlog: #$NUMBER $TITLE"
      gh issue edit "$NUMBER" --repo "$REPO" --add-label "hierarchy/backlog"
    else
      echo "  skip #$NUMBER (backlog-labeled but not a backlog item: $TITLE)"
    fi
  else
    # No epic, no backlog — check if it's an unlabeled backlog item
    # Issues #1-#22 and #122-#127 are backlog items without backlog/* labels
    if echo "$TITLE" | grep -qiE "^JWT auth|^Vector|^Smarter context|^Per-session|^Home automation|^Shell tool|^Image input|^Scheduled task|^Task result|^Push notification|^File system|^Proactive messages|^Pi deployment|^Reverse proxy|^Structured logging|^Usage metrics|^Automated database|^Replace InvokeToolAsync|^Fix appsettings|^Voice interface|^Proactive error|^Norris-initiated|^Cloud deployment|^Project bootstrapping|^Multi-repo|^Multi-feature|^Agentic SDLC as portable"; then
      echo "  backlog: #$NUMBER $TITLE"
      gh issue edit "$NUMBER" --repo "$REPO" --add-label "hierarchy/backlog"
    else
      echo "  skip #$NUMBER (unclassified: $TITLE)"
    fi
  fi

  # Rate limit: GitHub API has secondary rate limits on mutations
  sleep 0.5
done <<< "$ISSUES"

echo ""
echo "Done."
```

**Step 2: Review the script logic against the issue list**

Before running, dry-run mentally against known issues:
- #122 (SDLC Self-Orchestration) → `hierarchy/backlog` (has `backlog/*`, no `epic/*`)
- #132 ([#122/E01]) → `hierarchy/epic` (has `epic/*`, no `difficulty/*`)
- #135 ([#122/E01-S01]) → `hierarchy/story` (has `epic/*` + `difficulty/*`)
- #1 (JWT auth) → `hierarchy/backlog` (no labels, title-matched)
- #93 (Write implementation plan) → skip (has `backlog/*` but is a docs issue, not a backlog item)

**Step 3: Run the migration script**

Run: `chmod +x scripts/migrate-hierarchy-labels.sh && ./scripts/migrate-hierarchy-labels.sh`
Expected: Each issue gets classified and labeled. Watch for any "skip" or "unclassified" entries that might need manual attention.

**Step 4: Verify migration**

Run: `gh issue list --state all --label "hierarchy/backlog" --limit 50 --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Run: `gh issue list --state all --label "hierarchy/epic" --limit 50 --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Run: `gh issue list --state all --label "hierarchy/story" --limit 50 --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Expected: Backlog items, epics, and stories are correctly separated.

**Step 5: Commit the migration script**

```bash
git add scripts/migrate-hierarchy-labels.sh
git commit -m "chore(labels): apply hierarchy labels to all existing issues"
```

---

## Task 3: Standardize Backlog Label Colors

**Files:** None (GitHub API only)

All `backlog/*` labels should use `#5319E7` (deep purple). Currently some use different colors.

**Step 1: Update backlog label colors**

Run each command:
```bash
gh label edit "backlog/43-sdlc-v2" --color "5319E7"
gh label edit "backlog/57-test-sdlc-v2" --color "5319E7"
gh label edit "backlog/72-test-sdlc-v2-run2" --color "5319E7"
gh label edit "backlog/89-mythical-creatures" --color "5319E7"
gh label edit "backlog/106-travel-advisory" --color "5319E7"
gh label edit "backlog/122-sdlc-self-orchestration" --color "5319E7"
```

**Step 2: Verify colors**

Run: `gh label list --json name,color | jq '.[] | select(.name | startswith("backlog/"))'`
Expected: All six labels show color `5319E7`.

---

## Task 4: Delete GitHub Default Labels

**Files:** None (GitHub API only)

**Step 1: Delete all 9 unused default labels**

```bash
for label in "bug" "documentation" "duplicate" "enhancement" "good first issue" "help wanted" "invalid" "question" "wontfix"; do
  gh label delete "$label" --yes 2>/dev/null && echo "  deleted: $label" || echo "  not found: $label"
done
```

**Step 2: Verify deletion**

Run: `gh label list --json name | jq -r '.[].name' | sort`
Expected: No `bug`, `documentation`, `duplicate`, etc. Only `type/*`, `difficulty/*`, `hierarchy/*`, `backlog/*`, and `epic/*` (epic labels removed in next task).

---

## Task 5: Remove Epic Labels from Issues and Delete Epic Labels

**Files:** None (GitHub API only)

**Step 1: Write the epic label removal script**

Create `scripts/remove-epic-labels.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

REPO="carlosboeing/agentic-sdlc-workflow"

echo "Removing epic/* labels from all issues..."

# Get all epic label names
EPIC_LABELS=$(gh label list --repo "$REPO" --json name -q '.[].name' | grep "^epic/")

for LABEL in $EPIC_LABELS; do
  echo ""
  echo "Processing label: $LABEL"

  # Find all issues with this label
  ISSUES=$(gh issue list --state all --label "$LABEL" --limit 200 --repo "$REPO" --json number -q '.[].number')

  for NUMBER in $ISSUES; do
    echo "  removing from #$NUMBER"
    gh issue edit "$NUMBER" --repo "$REPO" --remove-label "$LABEL"
    sleep 0.5
  done

  # Delete the label itself
  echo "  deleting label: $LABEL"
  gh label delete "$LABEL" --repo "$REPO" --yes
done

echo ""
echo "Done. All epic/* labels removed and deleted."
```

**Step 2: Run the removal script**

Run: `chmod +x scripts/remove-epic-labels.sh && ./scripts/remove-epic-labels.sh`
Expected: All `epic/*` labels removed from issues, then the labels themselves deleted.

**Step 3: Verify no epic labels remain**

Run: `gh label list --json name | jq -r '.[].name' | grep "^epic/" || echo "No epic labels found"`
Expected: "No epic labels found"

**Step 4: Commit the removal script**

```bash
git add scripts/remove-epic-labels.sh
git commit -m "chore(labels): remove all epic/* labels from issues and delete them"
```

---

## Task 6: Update `setup-labels.sh` with Standard Colors Documentation

**Files:**
- Modify: `scripts/setup-labels.sh`

**Step 1: Add a comment documenting standard colors for dynamically-created labels**

Add after the hierarchy labels section:

```bash
echo ""
echo "Note: backlog/* labels are created dynamically by the planner agent."
echo "Standard color for backlog/* labels: 5319E7 (deep purple)"
echo ""
echo "Label color reference:"
echo "  hierarchy/backlog  = 6E40C9 (purple)"
echo "  hierarchy/epic     = E36209 (orange)"
echo "  hierarchy/story    = FBCA04 (yellow)"
echo "  backlog/*          = 5319E7 (deep purple)"
```

**Step 2: Commit**

```bash
git add scripts/setup-labels.sh
git commit -m "docs(labels): add standard color reference to setup-labels.sh"
```

---

## Task 7: Update CLAUDE.md Label Conventions

**Files:**
- Modify: `CLAUDE.md`

This is the largest documentation task. Multiple sections reference `epic/*` labels and need updating.

**Step 1: Update the Labels table**

Find the existing labels table (around line 138) and replace it with:

```markdown
**Labels:**

| Category | Labels | Purpose |
|----------|--------|---------|
| Hierarchy | `hierarchy/backlog`, `hierarchy/epic`, `hierarchy/story` | Identifies issue level for board filtering |
| Backlog | `backlog/<issue>-<slug>` | Groups all issues under a backlog item |
| Type | `type/feature`, `type/bug`, `type/refactor`, `type/test`, `type/docs` | Categorises work |
| Difficulty | `difficulty/easy`, `difficulty/medium`, `difficulty/hard` | Routes to model |
```

**Step 2: Update the issue hierarchy example**

The existing example shows `epic/eNN-slug` labels in the hierarchy diagram. Update to show `hierarchy/*` labels instead. The backlog label provides workstream grouping; hierarchy labels provide level identification.

**Step 3: Update epic-scoped telemetry reference**

Find the line (around 406):
```
**Epic-scoped telemetry:** When posting epic-level telemetry, include only stories that belong to that specific epic (check the `epic/` label).
```

Replace the `(check the \`epic/\` label)` parenthetical with `(check the epic's sub-issues)` since `epic/*` labels no longer exist.

**Step 4: Update planner issue creation example**

Find the `gh issue create` example that references `--label "epic/e01-slug,type/feature,difficulty/easy"` and update to use `--label "hierarchy/story,backlog/<issue>-<slug>,type/feature,difficulty/easy"`.

**Step 5: Update orchestrator story lookup reference**

The CLAUDE.md section about dispatching mentions finding stories by epic label. Update to reference finding stories via sub-issues or `backlog/*` + `hierarchy/story` filtering.

**Step 6: Add standard backlog label color convention**

Add a note in the label conventions section:

```markdown
**Label colors (standard):**

| Category | Hex | Notes |
|----------|-----|-------|
| `hierarchy/backlog` | `#6E40C9` | Purple |
| `hierarchy/epic` | `#E36209` | Orange |
| `hierarchy/story` | `#FBCA04` | Yellow |
| `backlog/*` | `#5319E7` | Deep purple — all dynamically-created backlog labels must use this color |
```

**Step 7: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(conventions): update CLAUDE.md label conventions for hierarchy labels"
```

---

## Task 8: Update Agent Files

**Files:**
- Modify: `.claude/agents/planner.md`
- Modify: `.claude/agents/orchestrator.md`
- Modify: `.claude/agents/builder.md`
- Modify: `.claude/agents/builder-haiku.md`
- Modify: `.claude/agents/builder-sonnet.md`
- Modify: `.claude/agents/builder-opus.md`
- Modify: `.claude/agents/reviewer.md`
- Modify: `.claude/agents/retro.md`

**Step 1: Update `planner.md`**

The planner creates issues with `epic/*` labels. Update:

- Line 115: `gh label create "epic/eNN-slug"` → Remove this line entirely (no more epic labels to create)
- Line 124: `--label "epic/e01-slug,type/feature,difficulty/easy"` → `--label "hierarchy/story,backlog/<issue>-<slug>,type/feature,difficulty/easy"`
- Line 134: `--label "epic/e01-slug"` → `--label "hierarchy/epic,backlog/<issue>-<slug>"`
- Add instruction that when creating a backlog item, apply `hierarchy/backlog`
- Add instruction that `backlog/*` labels must use color `5319E7`

**Step 2: Update `orchestrator.md`**

The orchestrator queries stories by `epic/*` label. Update:

- Line 95-96: The query that finds epic labels via `backlog/*` → Replace with using sub-issues to find epics
- Line 189: `gh issue list --label "epic/<slug>"` → `gh issue list --label "backlog/<slug>" --label "hierarchy/story"` (for stories) or use sub-issue traversal
- Line 331: `jq ... select(startswith("epic/"))` → Remove or replace with hierarchy label check
- Line 338: Keep `backlog/*` label lookup (unchanged)
- Line 341: `select(startswith("epic/"))` → Remove or replace
- Line 351-356: `EPIC_SLUG` and `EPIC_LABEL` derivation → Update to use hierarchy labels or sub-issues for epic identification

**Step 3: Update `builder.md`**

- Line 28: `gh issue list --label "epic/e01-slug"` → `gh issue list --label "backlog/<slug>" --label "hierarchy/story"`
- Line 91: branch reference `epic/eNN-slug` → keep (branch names don't change)
- Line 98: `git checkout -b epic/eNN-slug` → keep (branch names don't change)

**Step 4: Sync builder variants**

After updating `builder.md`, propagate to all three variants:

```bash
for variant in haiku sonnet opus; do
  sed "s/^name: builder$/name: builder-$variant/;s/^model: inherit$/model: $variant/" .claude/agents/builder.md > .claude/agents/builder-$variant.md
done
```

**Step 5: Update `reviewer.md`**

- Line 125: `epic/e01-dispatch-scripts` → This is a branch name reference, not a label. Keep as-is.
- Line 128: `git diff epic/<branch>...story-branch` → Keep (branch names don't change).

No label changes needed for reviewer — it references branch names (`epic/*`), not labels.

**Step 6: Update `retro.md`**

- Line 53-59: `git log main..epic/<branch-name>` → Keep (branch names).
- Line 88: `git diff main..epic/<branch-name>` → Keep (branch names).

No label changes needed for retro — all references are to branch names.

**Step 7: Commit**

```bash
git add .claude/agents/planner.md .claude/agents/orchestrator.md \
  .claude/agents/builder.md .claude/agents/builder-haiku.md \
  .claude/agents/builder-sonnet.md .claude/agents/builder-opus.md
git commit -m "docs(agents): update agent files for hierarchy label conventions"
```

---

## Task 9: Update Dispatch Scripts

**Files:**
- Modify: `scripts/dispatch-story.sh`
- Modify: `scripts/dispatch-workflow.sh`

**Step 1: Update `dispatch-story.sh`**

- Lines 80-90: The script extracts epic labels from issues. Update to use `hierarchy/*` labels or sub-issues instead of `epic/*` labels for identifying the epic branch. The branch name derivation (extracting `e01` from the title format `[E01-S01]`) can remain title-based since branch naming conventions are unchanged.

**Step 2: Update `dispatch-workflow.sh`**

- Line 331: `select(startswith("epic/"))` → Remove or replace with sub-issue traversal
- Line 338: Keep `backlog/*` lookup (unchanged)
- Line 341: `select(startswith("epic/"))` → Replace
- Lines 351-356: `EPIC_SLUG` / `EPIC_LABEL` / `EPIC_BRANCH` derivation → Derive branch name from title convention instead of label

**Step 3: Commit**

```bash
git add scripts/dispatch-story.sh scripts/dispatch-workflow.sh
git commit -m "fix(scripts): update dispatch scripts to use hierarchy labels instead of epic labels"
```

---

## Task 10: Clean Up Migration Scripts

**Files:**
- Delete: `scripts/migrate-hierarchy-labels.sh`
- Delete: `scripts/remove-epic-labels.sh`

**Step 1: Delete the one-time migration scripts**

```bash
rm scripts/migrate-hierarchy-labels.sh scripts/remove-epic-labels.sh
```

**Step 2: Commit**

```bash
git commit -m "chore: remove one-time label migration scripts"
```

---

## Task 11: Verify End State

**Files:** None

**Step 1: Verify label taxonomy**

Run: `gh label list --json name,color | jq -r 'sort_by(.name) | .[] | "\(.name)\t\(.color)"'`

Expected labels (and only these categories):
- `backlog/*` (all `5319E7`)
- `difficulty/*` (unchanged)
- `hierarchy/backlog` (`6E40C9`), `hierarchy/epic` (`E36209`), `hierarchy/story` (`FBCA04`)
- `type/*` (unchanged)

No `bug`, `documentation`, `duplicate`, `enhancement`, `good first issue`, `help wanted`, `invalid`, `question`, `wontfix`.
No `epic/*` labels.

**Step 2: Verify issue labels**

Run: `gh issue list --state all --limit 5 --label "hierarchy/story" --json number,title,labels | jq '.[0]'`
Expected: A story issue with `hierarchy/story`, `backlog/*`, `type/*`, `difficulty/*` — no `epic/*`.

**Step 3: Verify board filtering works**

Run: `gh issue list --state open --label "hierarchy/backlog" --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Expected: Only top-level backlog items.

Run: `gh issue list --state open --label "hierarchy/epic" --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Expected: Only epic issues.

Run: `gh issue list --state open --label "hierarchy/story" --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Expected: Only story issues.

**Step 4: Verify combined filtering**

Run: `gh issue list --state open --label "backlog/122-sdlc-self-orchestration" --label "hierarchy/story" --json number,title | jq -r '.[] | "#\(.number) \(.title)"'`
Expected: Only stories belonging to backlog #122.
