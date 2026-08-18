# coverage-map — a derived snapshot, **not** a source of truth

`metric-coverage.json` (118 rows) + `coverage-map.html`. Merged here 2026-08-18 from the
`hcv_selfserve` (underscore) directory in a third clone — see `../kb-build/DECISIONS.md` `D-028`.

## Read this before using it

**Its coverage fields are void.** All 118 rows carry `status: pending`, `blocker: not-started`,
`north_star: null`, `provenance: "stated"` and one identical `blocker_note`. That is a uniform stamp,
not an assessment — and on the **12** metrics with full write-ups, and on the FF %/Allocation %
series now warehouse-validated, it is **factually wrong**. → `../kb/GAPS.md` `G-082`

**Coverage lives in [`../kb/metrics.md`](../kb/metrics.md)** — §1 (12 full entries) and §2 (107 index
rows). This file must eventually be **generated from** that, so the two cannot diverge.

## What was harvested into the KB

1. **8 new customer/demand-side identities** — `HCV-103`, `104`, `105`, `106`, `107`, `110`, `113`,
   `115` → `metrics.md` §2 rows 100–107. A surface none of the first three sources carried.
2. **Thread ownership for 30 metrics** — LFC 20 · Core Platforms 6 · Marketplace 3 · Finance 1 →
   `metrics.md` §2d. **The only source that carries this.**

Everything else duplicates `metrics.md` §2 from the same Sheet lineage.

## Its own source is uncommitted

All 118 rows cite `ProdOps/02_specs_plans_logs/specs/2026-08-07-hcv-metric-mapping-design.md:17`,
which is outside this repo and has never been read by this KB. Under `../kb/CONTRIBUTING.md` §3 a
`local:`-only source **can never exceed `unverified`**. → `G-083`
