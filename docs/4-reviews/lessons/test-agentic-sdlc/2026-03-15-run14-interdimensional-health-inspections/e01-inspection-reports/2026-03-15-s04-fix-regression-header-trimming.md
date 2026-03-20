---
date: 2026-03-15
author: retro
story: "E01-S04 (#92) -- Special Event Inspection: The Probability Cafe"
tags: [builder, fix-cycle, regression, word-count, content]
severity: medium
---

# Builder Fix Regression: Header Fields Trimmed Instead of Body Prose

## What happened

When the reviewer flagged E01-S04's word count (444 words, 11% over 400-word limit), the builder's first fix (commit `5a97f20`) reduced the count from 444 to 399 by removing the `Document Type` header field and shortening `Inspector/Author` to `Inspector` and `Date of Inspection/Issue` to `Date`. The re-reviewer (dispatch 17) caught this as a header template regression, requiring a second fix cycle (commit `9aa16c7`).

## Root cause

The builder optimized for the word count constraint without considering the header template contract. Header fields are short strings that offer easy word savings, but they are structural elements shared across all documents in the epic. The reviewer's first REQUEST_CHANGES feedback suggested trimming "Required Corrective Actions" and "Executive Summary" sections, but the builder did not follow this guidance.

## Prevention

1. Reviewer feedback for word count issues should explicitly state: "Trim body prose only -- do not modify header template fields."
2. Builder agent instructions should include: "When trimming word count, never modify document header template fields. These are structural elements shared across all documents."
3. More generally, fix cycle instructions should emphasize preserving all acceptance criteria that already pass -- a fix for one AC violation must not regress another.
