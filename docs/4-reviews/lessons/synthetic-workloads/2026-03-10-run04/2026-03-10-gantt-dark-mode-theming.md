---
date: 2026-03-10
author: carlosboeing
agent: orchestrator
story: "Telemetry gantt chart theming (post-retro refinement)"
tags: [orchestrator, telemetry, mermaid, github, dark-mode, theming]
severity: high
---

# Mermaid Gantt Dark/Light Mode on GitHub

## What happened
Custom-themed Mermaid gantt charts were unreadable in GitHub dark mode. Tried 8+ approaches over multiple iterations: `theme: default`, `theme: base`, `theme: dark`, forced backgrounds (`background`, `sectionBkgColor`), mid-gray text, max contrast — none worked in both modes simultaneously.

## Root cause
GitHub's Viewscreen service auto-detects the user's dark/light preference and sets the Mermaid theme accordingly. Specifying **any** `theme` key in `%%{init}%%` (`default`, `base`, `dark`) overrides this auto-detection, locking in one mode's colors for both. Text colors, section backgrounds, grid lines, and title colors all get adapted by the theme engine — only `taskBkgColor` variants (bar fills) are preserved exactly as specified.

Reference: [GitHub community discussion #35733](https://github.com/orgs/community/discussions/35733)

## Prevention
Use `themeVariables` **without a `theme` key** in `%%{init}%%`:

```
%%{init: {'themeVariables':{
  'taskBkgColor':'#059669',
  'activeTaskBkgColor':'#8b5cf6',
  ...
}}}%%
```

This lets GitHub pick dark/light theme for text and backgrounds, then applies bar colors on top. Use 600-level Tailwind shades for ~4:1+ contrast with both white text (dark mode) and black text (light mode).

Colors are defined in `scripts/templates/telemetry.md` (single source of truth).
