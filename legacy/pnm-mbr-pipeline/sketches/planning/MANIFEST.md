# Sketch Manifest

## Design Direction
A calm, trust-first internal tool for asking Porter's PnM MBR metrics in plain English. The
**number is the hero** — big and legible — while the rendered read-only SQL and the disclosure
footer (open verify-flags, the nano rule, aggregate-then-ratio note, per-section readiness) sit
one tap away, never hidden. The feel blends **Metabase/Superset rigor** (a real metric catalog,
real SQL, explicit readiness states) with **ChatGPT/Perplexity clarity** (one answer at a time,
footnote-style disclosures). Muted warm-neutral palette, generous whitespace, legibility over
density. The design goal is *trust in the number*, not visual flash.

## Reference Points
- Metabase / Superset — internal BI query tools (catalog, SQL panel, readiness)
- ChatGPT / Perplexity — conversational answer + visible "sources" (here: SQL + flags as footnotes)

## Grounding data (real, from the eldoria re-point reconciliation, 2026-05)
leads 336,338 · orders 51,277 · conversion 15.25% · tpo_base 45,414 · 6 sections
(leads, orders, derived, tpo = reconciled/PROTOTYPE-ONLY; p80_durations, order_edits = not built; ota = blocked).
Nano rule: labour-only (LA-owned) — IN leads, OUT of orders & tpo.

## Sketches

| # | Name | Design Question | Winner | Tags |
|---|------|----------------|--------|------|
| 001 | answer-surface | How does a single answer present number + SQL + disclosure footer? | _pending_ | answer, disclosure, trust |
| 002 | app-shell | How do you browse the 6 sections & enter a question? | _not started_ | shell, catalog, nav |
