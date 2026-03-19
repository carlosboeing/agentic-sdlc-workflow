# ADR-0004: Shadow Stack Migration Strategy

**Date:** 2026-03-18
**Status:** Accepted
**Context:** Migration strategy for core workflow script changes — first applied in backlog #109 (PM Abstraction Layer)

## Context

Core workflow scripts — board management (`item-set-status.sh`, `batch-set-status.sh`, `reconcile-board.sh`), lifecycle tracking (`item-start.sh`, `item-review.sh`, `item-close.sh`), and telemetry (`item-telemetry.sh`) — are invoked by every agent in every run. They carry production traffic continuously: board status mutations, "Work Started" and "Ready for Review" comments, and telemetry posting all depend on these scripts being correct and available.

Modifying these scripts in-place poses a real risk:

1. **A bug introduced mid-refactor breaks the running workflow.** The orchestrator calls `item-set-status.sh` before and after every dispatch. If a refactor introduces a regression, the board goes silent and story tracking breaks — in the middle of a live run.

2. **Rollback of an in-place change is expensive.** If a modified script fails in production, `git revert` restores the script but any state mutations that already fired cannot be undone. A partial refactor leaves the codebase in an inconsistent state.

3. **Testing in-place refactors requires mocking the live system.** Unit tests for the existing scripts must be written against the modified behavior before the change lands — difficult when the change is the removal of inline GitHub API calls.

The PM Abstraction Layer (backlog #109) is the first large-scale refactor of these core scripts. It introduces `scripts/lib/pm.sh` and `scripts/lib/adapters/pm/github/` as replacements for the inline `gh` CLI and GraphQL calls currently embedded across 15+ scripts. This migration touched every agent's entry and exit path.

A disciplined migration strategy was needed to ensure the running workflow could not be broken during the refactor.

## Decision

All future core workflow changes follow a three-phase **shadow stack** pattern:

### Phase 1: Build Alongside

Create the new code in new files and folders. Do not touch existing scripts. The running workflow uses existing scripts throughout this phase.

**Rule:** No existing file may be modified during Phase 1. If a shared utility must change, it is copied into the new code and modified there. Existing scripts continue to call the old version.

**Example (PM Abstraction):**

```
# New files created — existing files untouched
scripts/lib/pm.sh                           # Adapter loader + public API
scripts/lib/adapters/pm/github/items.sh     # pm_create_item, pm_get_item, pm_list_items, pm_close_item
scripts/lib/adapters/pm/github/board.sh     # pm_set_status, pm_batch_set_status, pm_reconcile
scripts/lib/adapters/pm/github/comments.sh  # pm_add_comment, pm_post_telemetry
scripts/lib/adapters/pm/github/hierarchy.sh # pm_link_child
scripts/lib/adapters/pm/github/labels.sh    # pm_add_label
```

**Validation:** Write unit tests for the new code before touching any existing script. The test suite must pass against the new adapter in isolation, with no dependency on the scripts being replaced.

### Phase 2: Shadow Verify (optional)

Existing scripts call both the old and new paths, compare results. Discrepancies are logged, not fatal. The old path remains authoritative — failures in the shadow path do not affect callers.

**Example (PM Abstraction):**

```bash
# scripts/item-set-status.sh — shadow mode
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"

# Primary path (existing logic — authoritative)
LEGACY_RESULT=$(_legacy_set_status "$@")

# Shadow path (new adapter — compare only, never fails the caller)
SHADOW_RESULT=$(pm_set_status "$@" 2>&1) || true
if [ "$SHADOW_RESULT" != "$LEGACY_RESULT" ]; then
  echo "SHADOW_MISMATCH: legacy=$LEGACY_RESULT new=$SHADOW_RESULT" \
    >> .agentic-workflow/logs/shadow.log
fi
```

Shadow verify is a **stretch goal**. It provides confidence before the swap, particularly for scripts with complex side effects (board mutations, comment posting). If time-constrained, skip directly to Phase 3.

### Phase 3: Swap

Existing scripts become thin wrappers that delegate to the new code. The old logic is deleted from individual scripts. The new stack carries all production traffic.

**Rule:** The swap is a single commit. One `git revert` of that commit fully restores the old behavior.

**Example (PM Abstraction):**

```bash
# scripts/item-set-status.sh — after swap
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/pm.sh"
pm_set_status "$@"
```

**Scripts that become wrappers in the PM migration:**

| Script | Delegates to |
|--------|-------------|
| `item-set-status.sh` | `pm_set_status` |
| `batch-set-status.sh` | `pm_batch_set_status` |
| `item-start.sh` | `pm_start_work` |
| `item-review.sh` | `pm_complete_work` |
| `item-close.sh` | `pm_close_item` |
| `item-create.sh` | `pm_create_item` + `pm_add_to_board` + `pm_set_status` + `pm_add_label` |
| `reconcile-board.sh` | `pm_reconcile` |
| `setup-labels.sh` | `pm_add_label` (repeated calls) |

**Rollback plan:** If the new adapter causes failures in production:

1. `git revert <swap-commit>` — restores all wrapper scripts to their pre-swap state in one operation
2. The adapter stack remains in `scripts/lib/adapters/pm/github/` but is no longer called
3. Debug the adapter independently, then re-swap

The rollback is safe because the adapter files are **additive** — reverting the wrappers restores original behavior without deleting new code. No data is lost.

## Alternatives Considered

### 1. In-Place Refactor

Modify existing scripts directly. Write tests before modifying, validate after. No new file structure.

- **Pro:** Simplest — no parallel code paths.
- **Con:** Any bug introduced during refactor immediately breaks production traffic. Rollback requires reverting multiple files that may have been modified in separate commits.
- **Con:** Cannot test the new behavior independently before it goes live — the "new behavior" replaces the "old behavior" at the moment of commit.
- **Rejected** because core scripts carry continuous production traffic and a partial refactor leaves the system in an undefined state.

### 2. Feature Flags

Add a config flag (e.g., `"pm.mode": "legacy" | "adapter"`) that switches the script's code path at runtime.

- **Pro:** Allows gradual rollout without file changes.
- **Con:** Flag logic must be added to every existing script that calls GitHub APIs — 15+ files. The flag logic itself is a source of bugs.
- **Con:** The flag must be removed after migration, requiring a second round of changes to the same files.
- **Con:** Two code paths in the same file are harder to reason about than two separate files.
- **Rejected** because it adds complexity in the same place the complexity is being removed.

### 3. Full Rewrite

Replace all existing scripts with a clean implementation simultaneously. No transition period.

- **Pro:** The cleanest end state — no wrappers, no duplication.
- **Con:** Any regression in the new code breaks all production traffic immediately. No gradual verification.
- **Con:** For 15+ scripts, a simultaneous rewrite increases the risk surface to the maximum.
- **Con:** Rollback requires reverting all rewritten files, which may conflict with other changes made during the rewrite window.
- **Rejected** because the risk is proportional to the scope of the rewrite. The shadow stack achieves the same end state with lower risk at the cost of one additional commit (the swap).

## Consequences

**Positive:**

- **Zero-risk development phase.** New code can be built, tested, and reviewed independently before it carries any production traffic. Bugs in Phase 1 are caught by unit tests, not by a broken live run.
- **Single-commit rollback.** The swap commit is the entire migration. Reverting it fully restores the previous behavior. No partial-revert archaeology.
- **Shadow verification catches behavioral differences.** Optional Phase 2 provides an audit trail of any divergence between old and new paths before the swap. This is especially useful for scripts with complex side effects (board mutations, telemetry posting) where behavioral equivalence is hard to assert in unit tests alone.
- **Additive first, destructive last.** The pattern respects the principle that production systems should be extended before they are modified. Deletion happens only after the replacement is verified.

**Negative:**

- **Temporary code duplication.** During Phase 1 (and Phase 2 if used), the old logic and new logic both exist. A change to the underlying GitHub API during Phase 1 must be applied to both. This duplication window should be kept short.
- **Phase 2 complexity.** The shadow verify wiring adds lines to existing scripts that must be removed at Phase 3. Under time pressure, this phase is skipped — but skipping it means the swap has less empirical confidence.

## Applicability

**This ADR applies to changes that affect:**

- Scripts called by multiple agents (board management, telemetry, state)
- Core infrastructure used on the critical path of every run
- Config schema changes that alter runtime behavior
- Adapter interfaces that will have multiple implementations

**This ADR does NOT apply to:**

- Agent `.md` file updates (no runtime side effects; a bad agent file change can be reverted without affecting live production state)
- Documentation changes (no runtime impact)
- Adding new scripts that do not replace existing ones (additive-only changes carry no rollback risk)
- Bug fixes to individual scripts with narrow callers (a fix to a diagnostic-only script does not need shadow verification)

**First application:** Backlog #109 — PM Abstraction Layer. The GitHub adapter (`scripts/lib/adapters/pm/github/`) was built alongside the existing scripts (Phase 1) across epics E01 and E02. Phase 2 (shadow verify) was designated a stretch goal. Phase 3 (swap) converts existing scripts to thin wrappers and is targeted for a subsequent story.

**Future applications:** Any change that touches `item-set-status.sh`, `item-telemetry.sh`, `state.sh`, or `reconcile-board.sh` should follow this pattern. VCS abstraction (`vcs.sh`, if and when built) is the next expected application.
