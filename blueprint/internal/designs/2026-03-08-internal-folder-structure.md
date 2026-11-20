# Internal Folder Structure Design

Design for organizing the `internal/` directory as a structured working space for iterating on the blueprint, implementations, and starter kit.

## 1. Context

The `internal/` folder holds maintainer-facing documents that support the blueprint's evolution — audits, design proposals, research, and session logs. As iteration accelerates with Claude Code, this folder needs a clear structure and naming convention that any contributor can follow regardless of which CC plugins they have installed.

## 2. Design Decisions

### 2.1 Organization: By Type

Documents are grouped by type (designs, plans, reviews) rather than by topic or chronology. Rationale:

- Type-based folders make it easy to find "all designs" or "all decisions" without knowing the topic name
- Topic-based folders fragment related documents across many small directories
- Chronological flat structures become unnavigable beyond ~20 files

### 2.2 Naming Convention

All files follow `YYYY-MM-DD-<topic-in-kebab-case>.md`. Date prefix enables chronological sorting within each type folder. No type suffix (e.g., `-design`) since the folder provides the type.

### 2.3 Enforcement via CLAUDE.md

The convention is enforced through CLAUDE.md project instructions, which every CC user reads regardless of installed plugins. This overrides any skill-specific defaults (e.g., the brainstorming skill's default `docs/plans/` output path).

## 3. Folder Structure

```
internal/
├── audits/       Periodic quality and completeness assessments
├── decisions/    Decision records explaining why X was chosen over Y
├── designs/      Design docs from brainstorming and ideation
├── notes/        Session notes and daily logs
├── plans/        Implementation plans for approved designs
├── research/     Technical investigations, paper analyses, reference digests
└── reviews/      Code reviews, design reviews, post-implementation reviews
```

## 4. CC Skill Overrides

| Skill Output | Default Path | Override Path |
|---|---|---|
| Brainstorming design docs | `docs/plans/YYYY-MM-DD-<topic>-design.md` | `internal/designs/YYYY-MM-DD-<topic>.md` |
| Implementation plans | `docs/plans/YYYY-MM-DD-<topic>-plan.md` | `internal/plans/YYYY-MM-DD-<topic>.md` |

## 5. Migration

| Current Path | New Path |
|---|---|
| `internal/proposed-improvements.md` | `internal/designs/2026-03-07-proposed-improvements.md` |
| `internal/audits/audit-report-2026-03-07.md` | `internal/audits/2026-03-07-blueprint-audit.md` |
