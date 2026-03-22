---
date: 2026-03-10
author: carlosboeing
agent: orchestrator
status: draft
purpose: housekeeping
---

# Test Issue Cleanup Plan

## Context

Six SDLC test runs (Runs 1–6) were executed to validate and refine the agentic workflow. Each run created a backlog issue, epics, stories, design doc issues, and plan issues — all producing markdown test content (not production code). These issues have served their purpose and now clutter the GitHub project board and issue tracker.

## Objective

Delete all test run issues and their associated labels. Preserve all real feature issues, open backlog items, and pull requests (git history).

## Scope

### In scope

- 72 GitHub issues across 6 test runs
- 6 `backlog/*` labels used exclusively by test runs
- Removal of deleted issues from the GitHub Project board (automatic when issues are deleted)

### Out of scope

- Pull requests (MERGED state) — these are part of git history and must not be deleted
- Real feature issues (#1–55 except test items, #122–143)
- Open backlog items (#1–22, #88, #123–131)
- Any files in the repository (test output content, docs, plans)

## Discovery Method

1. Found all 6 backlog issues by searching for titles matching `Test SDLC v2 Workflow`
2. Traced children using `backlog/*` labels on each backlog issue
3. Cross-referenced issue number gaps to find orphaned issues without `backlog/*` labels (#69, #71, #91, #107, #109)
4. Verified each number is an issue (not a PR) by checking state — PRs show as `MERGED`

## Deletion List

### Run 1 (#57) — Creative Writing Suite — 14 issues


| #   | Title                                              | State  | Type    |
| --- | -------------------------------------------------- | ------ | ------- |
| 57  | Test SDLC v2 Workflow — Creative Writing Suite     | CLOSED | backlog |
| 58  | [#57/E01] Poetry Collection                        | CLOSED | epic    |
| 59  | [#57/E02] Sci-Fi Story                             | CLOSED | epic    |
| 60  | [#57/E01-S01] Haiku Collection                     | CLOSED | story   |
| 61  | [#57/E01-S02] Limerick Collection                  | CLOSED | story   |
| 62  | [#57/E01-S03] Sonnets + Analysis                   | CLOSED | story   |
| 63  | [#57/E01-S04] Poetry Anthology                     | CLOSED | story   |
| 64  | [#57/E02-S01] Character Profiles                   | CLOSED | story   |
| 65  | [#57/E02-S02] World-Building Document              | CLOSED | story   |
| 66  | [#57/E02-S03] Chapter 1: First Contact             | CLOSED | story   |
| 67  | [#57/E02-S04] Chapter 2: The Betrayal              | CLOSED | story   |
| 68  | [#57/E02-S05] Epilogue + Literary Review           | CLOSED | story   |
| 69  | fix(scripts): remove unsupported --max-turns flag  | CLOSED | bug fix |
| 71  | Convention changes from E01/E02 Test SDLC v2 retro | CLOSED | retro   |


### Run 2 (#72) — Recipe/Travel/Board Game — 16 issues


| #   | Title                                           | State  | Type    |
| --- | ----------------------------------------------- | ------ | ------- |
| 72  | Test SDLC v2 Workflow (Run 2)                   | CLOSED | backlog |
| 73  | [#72/E01] Recipe Book                           | CLOSED | epic    |
| 74  | [#72/E02] Travel Guide                          | CLOSED | epic    |
| 75  | [#72/E03] Board Game Design                     | CLOSED | epic    |
| 76  | [#72/E01-S01] Breakfast recipes                 | CLOSED | story   |
| 77  | [#72/E01-S02] Dinner recipes                    | CLOSED | story   |
| 78  | [#72/E01-S03] Nutritional analysis              | CLOSED | story   |
| 79  | [#72/E01-S04] Weekly meal planner               | CLOSED | story   |
| 80  | [#72/E02-S01] Island geography                  | CLOSED | story   |
| 81  | [#72/E02-S02] Points of interest                | CLOSED | story   |
| 82  | [#72/E02-S03] Culture & language guide          | CLOSED | story   |
| 83  | [#72/E02-S04] 3-day itinerary                   | CLOSED | story   |
| 84  | [#72/E02-S05] Travel budget & packing list      | CLOSED | story   |
| 85  | [#72/E03-S01] Game concept & victory conditions | CLOSED | story   |
| 86  | [#72/E03-S02] Complete rulebook                 | CLOSED | story   |
| 87  | [#72/E03-S03] Components & quick-start          | CLOSED | story   |


### Run 3 (#89) — Mythical Creatures Field Guide — 12 issues


| #   | Title                                                        | State  | Type    |
| --- | ------------------------------------------------------------ | ------ | ------- |
| 89  | Test SDLC v2 Workflow (Run 3) — Full Autonomous Lifecycle    | CLOSED | backlog |
| 91  | Write design doc for Mythical Creatures Field Guide          | CLOSED | docs    |
| 93  | Write implementation plan for Mythical Creatures Field Guide | CLOSED | docs    |
| 94  | [#89/E01] Creature Compendium                                | CLOSED | epic    |
| 95  | [#89/E02] Field Operations Manual                            | CLOSED | epic    |
| 96  | [#89/E01-S01] Classification Taxonomy                        | CLOSED | story   |
| 97  | [#89/E01-S02] Creature Profile — Emberwing Drake             | CLOSED | story   |
| 98  | [#89/E01-S03] Creature Profile — Mirrorghast                 | CLOSED | story   |
| 99  | [#89/E01-S04] Creature Profile — Stoneback Leviathan         | CLOSED | story   |
| 100 | [#89/E02-S01] Field Notes — The Thornwood Expedition         | CLOSED | story   |
| 101 | [#89/E02-S02] Danger Classification Matrix                   | CLOSED | story   |
| 102 | [#89/E02-S03] Survival Protocols                             | CLOSED | story   |


### Run 4 (#106) — Intergalactic Travel Advisory — 10 issues


| #   | Title                                                       | State    | Type    |
| --- | ----------------------------------------------------------- | -------- | ------- |
| 106 | Test SDLC v2 Workflow (Run 4) — Autonomous Sprint           | CLOSED   | backlog |
| 107 | Design doc: Intergalactic Travel Advisory                   | CLOSED   | docs    |
| 109 | Write implementation plan for Intergalactic Travel Advisory | **OPEN** | docs    |
| 110 | [#106/E01] Destination Profiles                             | CLOSED   | epic    |
| 111 | [#106/E02] Advisory Supplements                             | CLOSED   | epic    |
| 112 | [#106/E01-S01] Kepler-442b — The Resort World               | CLOSED   | story   |
| 113 | [#106/E01-S02] Gliese-667c — Extreme Tourism                | CLOSED   | story   |
| 114 | [#106/E01-S03] Proxima Station — Orbital Bazaar             | CLOSED   | story   |
| 115 | [#106/E02-S01] Packing Checklist                            | CLOSED   | story   |
| 116 | [#106/E02-S02] Safety Incident Report                       | CLOSED   | story   |


> ⚠️ **#109 is OPEN** — was never closed after Run 4 completed. Will be deleted along with the rest.

### Run 5 (#146) — DoomCo Supervillain Handbook — 10 issues


| #   | Title                                                              | State  | Type    |
| --- | ------------------------------------------------------------------ | ------ | ------- |
| 146 | Test SDLC v2 Workflow (Run 5) — Autonomous Sprint                  | CLOSED | backlog |
| 147 | Write design doc for Supervillain Employee Handbook                | CLOSED | docs    |
| 149 | Write implementation plan for Supervillain Employee Handbook       | CLOSED | docs    |
| 150 | [#146/E01] Role Profiles                                           | CLOSED | epic    |
| 151 | [#146/E02] Company Policies                                        | CLOSED | epic    |
| 152 | [#146/E01-S01] Role Profile — Mad Scientist                        | CLOSED | story   |
| 153 | [#146/E01-S02] Role Profile — Henchman (General)                   | CLOSED | story   |
| 154 | [#146/E01-S03] Role Profile — Executive Villain (C-Suite)          | CLOSED | story   |
| 155 | [#146/E02-S01] Lair Safety & Compliance Guidelines                 | CLOSED | story   |
| 156 | [#146/E02-S02] Hero Encounter Protocols & Monologue Best Practices | CLOSED | story   |


### Run 6 (#162) — Cat Performance Review — 10 issues


| #   | Title                                                                | State  | Type    |
| --- | -------------------------------------------------------------------- | ------ | ------- |
| 162 | Test SDLC v2 Workflow (Run 6) — Single-PR Workflow                   | CLOSED | backlog |
| 163 | Write design doc for Cat Performance Review (Run 6)                  | CLOSED | docs    |
| 165 | Write implementation plan for Cat Performance Review                 | CLOSED | docs    |
| 166 | [#162/E01] Human Employee Reviews                                    | CLOSED | epic    |
| 167 | [#162/E02] HR Policies & Procedures                                  | CLOSED | epic    |
| 168 | [#162/E01-S01] Performance Review — The Work-From-Home Human         | CLOSED | story   |
| 169 | [#162/E01-S02] Performance Review — The Early Riser                  | CLOSED | story   |
| 170 | [#162/E01-S03] Performance Review — The One Who Got a Dog            | CLOSED | story   |
| 171 | [#162/E02-S01] Feline Workplace Standards & Human Conduct Guidelines | CLOSED | story   |
| 172 | [#162/E02-S02] Disciplinary Procedures & Termination Protocols       | CLOSED | story   |


### Labels to delete — 6


| Label                                | Used by |
| ------------------------------------ | ------- |
| `backlog/57-test-sdlc-v2`            | Run 1   |
| `backlog/72-test-sdlc-v2-run2`       | Run 2   |
| `backlog/89-mythical-creatures`      | Run 3   |
| `backlog/106-travel-advisory`        | Run 4   |
| `backlog/146-doomco-handbook`        | Run 5   |
| `backlog/162-cat-performance-review` | Run 6   |


## Summary


|                             | Count |
| --------------------------- | ----- |
| Issues to delete            | 72    |
| Labels to delete            | 6     |
| PRs affected                | 0     |
| Real features affected      | 0     |
| Open backlog items affected | 0     |


## Execution

### Pre-flight checks

1. Verify each number is an issue (not a PR) before deleting
2. Confirm no open backlog items are in the list

### Deletion order

1. Delete issues (children first, then epics, then backlogs — avoids orphan warnings)
2. Delete labels (after issues, since labels on deleted issues are already detached)

### Post-flight verification

1. Confirm issue count: `gh issue list --state all --limit 200` should show no test run issues
2. Confirm board: `gh project item-list 7 --owner carlosboeing --format json --limit 200` should not contain deleted issue numbers
3. Confirm labels: `gh label list` should not contain the 6 deleted labels

## Not Deleted (for reference)

These items were reviewed and explicitly excluded:


| #                                                                            | Title                              | Reason                               |
| ---------------------------------------------------------------------------- | ---------------------------------- | ------------------------------------ |
| #56, #70, #90, #92, #103–105, #108, #117–121, #144–145, #148, #157–161, #164 | Various PRs                        | Pull requests (MERGED) — git history |
| #88                                                                          | Agentic SDLC as portable CC plugin | Real open backlog item               |
| #1–22                                                                        | Various backlog items              | Real open backlog items              |
| #123–131                                                                     | Various backlog items              | Real open backlog items              |
| #5, #24–55                                                                   | Calendar tool + SDLC v2 feature    | Real shipped features                |
| #122, #132–143                                                               | SDLC Self-Orchestration            | Real shipped feature                 |


