---
sketch: 001
name: answer-surface
question: "How does a single answer present the number + rendered SQL + disclosure footer?"
winner: null
tags: [answer, disclosure, trust]
---

# Sketch 001: Answer Surface

## Design Question
When a user asks one PnM metric question, how do we present the **answer (number)**, the
**rendered read-only SQL**, and the **disclosure footer** (open verify-flags, nano rule,
aggregate-then-ratio, per-section readiness) so the number is trusted and the "show your work"
is one tap away — never hidden, never noisy?

## How to View
open .planning/sketches/001-answer-surface/index.html

(Switch variants with the tabs at the top. Toolbar bottom-right: theme + viewport. All three use
the real reconciled 2026-05 figure, tpo base = 45,414.)

## Variants
- **A: Stacked disclosure** — big number + status pill, then two calm collapsible sections
  (*Show SQL*, *Disclosures*) stacked below. Purest "calm, trust-first." Includes a readiness
  state cycler (reconciled / prototype-only / not-built / blocked).
- **B: Persistent trust rail** — answer + SQL on the left, a right rail that *always* shows the
  trust checklist (reconciled, nano rule, aggregate-then-ratio, verify-flags, source). Metabase
  rigor: disclosures are never collapsed away.
- **C: Conversational thread** — Perplexity style. Question bubble → answer card with the number,
  footnote chips (¹²³) that jump to a disclosures list, an expandable SQL block, and an
  "ask a follow-up" box. Shows a second Q&A to convey the thread.

## What to Look For
- **Where should disclosures live?** Collapsed by default (A/C) vs always-visible rail (B).
  Which makes you *trust* the number faster without feeling nagged?
- **Is the number the hero** in each, or does the SQL/flag machinery compete with it?
- **Readiness states** — cycle A through prototype-only / not-built / blocked. Does the same
  surface degrade gracefully when a section isn't ready?
- **Footnote chips vs labelled panels** — does C's ¹²³ pattern read as rigorous or as clutter
  for a data-literate internal user?
