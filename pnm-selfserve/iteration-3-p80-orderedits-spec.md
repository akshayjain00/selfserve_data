# Iteration 3 — Build `p80_durations` + `order_edits` (design spec)

*Status: DRAFT for owner review · 2026-07-12 · PROTOTYPE-ONLY (no section becomes stakeholder-ready except by the owner) · Author: Claude (orchestrator), grounded on two read-only explorer passes.*

This spec turns the `HANDOFF-p80-orderedits-orchestration.md` pointer doc into a concrete, reviewable design. It does **not** re-derive decision history — see `DECISION_LOG.md` (D1–D7, V1–V3) and `HANDOFF.md`.

---

## 1. Goal & scope

Build the two remaining report sections by **mirroring the owner's live-validated MBR automation** (`…/ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py`), then prove them with live differential reconciliation.

**In scope (this iteration):**
- `p80_durations` — mirror `TRIP_DURATION_PERCENTILE_QUERY` (7 metrics).
- `order_edits` — mirror `EDIT_ADOPTION_QUERY` (10 metrics).
- Extend the dry-run harness; reconcile live vs the automation (≥1 month, targeting more).

**Out of scope (unchanged):**
- `ota` — stays **BLOCKED** (no clean data source defined).
- Industry-practice research synthesis (semantic layer / multi-agent patterns) — **deferred** by owner.
- Formalizing this as a Claude Code skill; opening any stakeholder access — **owner-only**, not this iteration.

---

## 2. Confirmed decisions (proposed DECISION_LOG entries D8–D10)

- **D8 — Source table for both new sections = `PROD_ELDORIA.MART.PNM_EXPERIENCE`.** Mirrors the *current* validated automation (both queries `.format(source_table=config.EXPERIENCE_SOURCE_TABLE)` → this mart). **This supersedes** the stale in-repo notes that pointed p80 at `FACT_PNM_ORDERS` and order_edits at `sr_modifications`/`order_modifications`. Rationale: the p80 baseline CSV *is* this automation's output; sourcing elsewhere would diverge from the very baseline we validate against. The registry's `ORDERS_SOURCE_DECISION` warning ("don't mirror literally — it reads raw `pnm_application.orders`") referred to a **legacy** automation; the current one reads this governed mart. Owner-confirmed 2026-07-12.
- **D9 — Metric IDs = the automation's exact output-column names** (e.g. `p80_trip_duration`, `pct_orders_edited`), **not** the iteration-1 `_mins`-suffixed catalog names. Rationale: `ask.compute_value` does `row.get(metric_id)`, so a `sql`-sourced `metric_id` must equal its SQL column alias; using the automation's names keeps reconciliation as pure field-by-field equality. The `_mins` ids were never built, so this is free to supersede.
- **D10 — `p50_trip_duration` is emitted + reconciled but not NL-exposed.** The automation emits it and the baseline CSV has it (needed for exact reconciliation), but the resolver's closed-world guard refuses `p50`/`median`. Keep the guard; expose `p50_trip_duration` only via `ask.py --metric` (never NL); disclose the asymmetry in a `verify_flag`. Owner-confirmed 2026-07-12.

---

## 3. Pre-flight — live schema verification (**first build step, gates all SQL**)

`PNM_EXPERIENCE` is flagged in-file as a mart "still under active construction" whose schema "grew between two verifications a day apart." Before writing any `sqlgen` SQL, verify (read-only, via the Snowflake MCP) that **every** required column exists live. If any are missing/renamed, STOP and surface to owner — do not guess.

Required columns (20):

| Group | Columns |
|---|---|
| Filters / keys | `ORDER_STATUS`, `PACKAGE_NAME`, `SHIFTING_TYPE`, `ORDER_ID` |
| p80 grain + stages | `SHIFTING_TS_IST`, `VENDOR_OWNER_ACCEPTED_TS_IST`, `SUPERVISOR_ACCEPTED_TS_IST`, `TRIP_STARTED_TS_IST`, `SHIFTING_STARTED_TS_IST`, `PICKUP_COMPLETED_TS_IST`, `ORDER_COMPLETED_TS_IST` |
| order_edits grain + flags | `ORDER_CREATED_TS_IST`, `IS_MODIFICATION_DONE`, `NO_OF_SUCCESSFUL_EDITS`, `EDITS_AFTER_SHIFTING`, `HAS_SUPPORT_EDIT`, `HAS_LOCATION_EDIT`, `HAS_ITEMS_EDIT`, `HAS_ADDONS_EDIT`, `HAS_SLOT_EDIT` |

Check via `INFORMATION_SCHEMA.COLUMNS` (authoritative, live) — not the Data Catalog (which may lag this fast-moving mart).

---

## 4. The mirror SQL (single-month adaptation)

Structure-only adaptation per D7: the automation's open-ended `>= start_date` + `GROUP BY month` becomes a single requested month, expressed as a **prunable range** (`ts >= '{month_start}' AND ts < DATEADD('month', 1, DATE '{month_start}')`) — honours the micro-partition-pruning rule (no function wrapping the column) *and* reconciles to exactly the automation's row for that month. Every section emits `DATE '{month_start}' AS month` as column 1 (the `ask.py` match contract). No IST shift needed — columns are already `_TS_IST`.

### 4a. `p80_durations`
```sql
SELECT
    DATE '{month_start}' AS month,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', VENDOR_OWNER_ACCEPTED_TS_IST, SUPERVISOR_ACCEPTED_TS_IST)), 1) AS p80_vendor_accepted_to_sup_assigned,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SUPERVISOR_ACCEPTED_TS_IST, TRIP_STARTED_TS_IST)), 1)           AS p80_sup_assigned_to_trip_started,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', TRIP_STARTED_TS_IST, SHIFTING_STARTED_TS_IST)), 1)              AS p80_trip_started_to_shifting_started,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, PICKUP_COMPLETED_TS_IST)), 1)          AS p80_shifting_started_to_pickup_complete,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', PICKUP_COMPLETED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p80_pickup_complete_to_order_complete,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p50_trip_duration,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p80_trip_duration
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
WHERE SHIFTING_TS_IST >= '{month_start}'
  AND SHIFTING_TS_IST <  DATEADD('month', 1, DATE '{month_start}')
  AND ORDER_STATUS = 'completed'
  AND PACKAGE_NAME NOT ILIKE 'Nano%'
  AND SHIFTING_TYPE = 'intra_city'
```
Single filtered month → one implicit group; the literal `month` is constant, so no `GROUP BY`.

### 4b. `order_edits`
```sql
WITH base AS (
    SELECT
        COUNT(DISTINCT pe.ORDER_ID)                                                     AS total_orders,
        COUNT(DISTINCT CASE WHEN pe.IS_MODIFICATION_DONE = 'Yes' THEN pe.ORDER_ID END) AS orders_with_mods,
        SUM(pe.NO_OF_SUCCESSFUL_EDITS)                                                  AS no_of_successful_edits,
        SUM(pe.EDITS_AFTER_SHIFTING)                                                    AS edits_after_shifting,
        COUNT(DISTINCT CASE WHEN pe.HAS_SUPPORT_EDIT  = 1 THEN pe.ORDER_ID END)         AS support_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_LOCATION_EDIT = 1 THEN pe.ORDER_ID END)         AS location_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ITEMS_EDIT    = 1 THEN pe.ORDER_ID END)         AS items_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ADDONS_EDIT   = 1 THEN pe.ORDER_ID END)         AS addons_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_SLOT_EDIT     = 1 THEN pe.ORDER_ID END)         AS slot_edited_orders
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    WHERE pe.ORDER_CREATED_TS_IST >= '{month_start}'
      AND pe.ORDER_CREATED_TS_IST <  DATEADD('month', 1, DATE '{month_start}')
      AND pe.ORDER_STATUS = 'completed'
      AND pe.SHIFTING_TYPE = 'intra_city'
      AND pe.PACKAGE_NAME NOT ILIKE 'Nano%'
)
SELECT
    DATE '{month_start}' AS month,
    ROUND(100.0 * orders_with_mods       / NULLIF(total_orders, 0), 2)           AS pct_orders_edited,
    no_of_successful_edits,
    ROUND(100.0 * support_edited_orders  / NULLIF(total_orders, 0), 2)           AS pct_support_edited_orders,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS location_adoption_pct,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS pct_orders_location_modified,
    ROUND(100.0 * items_edited_orders    / NULLIF(total_orders, 0), 2)           AS items_adoption_pct,
    ROUND(100.0 * addons_edited_orders   / NULLIF(total_orders, 0), 2)           AS addons_adoption_pct,
    ROUND(100.0 * slot_edited_orders     / NULLIF(total_orders, 0), 2)           AS slot_adoption_pct,
    ROUND(no_of_successful_edits * 1.0   / NULLIF(total_orders, 0), 2)           AS edits_per_order,
    ROUND(100.0 * edits_after_shifting   / NULLIF(no_of_successful_edits, 0), 2) AS pct_edits_after_shifting_started
FROM base
```
Note the denominators: **#10 (`pct_edits_after_shifting_started`) divides by `no_of_successful_edits`**, all other % by `total_orders`. Intermediate counts (`total_orders`, …) are **not** emitted (exact mirror) — see §9 sample-size open item.

---

## 5. Metric catalog

**`p80_durations`** (`readiness: prototype_only`, `month_basis: SHIFTING_TS_IST`, unit: minutes):

| metric_id (= column) | NL-exposed? | Notes |
|---|---|---|
| `p80_vendor_accepted_to_sup_assigned` | **No** (`--metric` only) | Name contains "vendor" → hits `UNSUPPORTED_TERMS` guard (see §8). |
| `p80_sup_assigned_to_trip_started` | Yes | quirk: "Supervisor Assigned" reads `SUPERVISOR_ACCEPTED_TS_IST`. |
| `p80_trip_started_to_shifting_started` | Yes | |
| `p80_shifting_started_to_pickup_complete` | Yes | |
| `p80_pickup_complete_to_order_complete` | Yes | label quirk: "…→ Shifting Complete". |
| `p50_trip_duration` | **No** (`--metric` only) | D10 — p50 guard. |
| `p80_trip_duration` | Yes | Shifting Started → Order Completed. |

**`order_edits`** (`readiness: prototype_only`, `month_basis: ORDER_CREATED_TS_IST`, units: % or count): all 10 NL-exposed. `location_adoption_pct` and `pct_orders_location_modified` are the **duplicate-by-design** pair (identical value; distinct aliases required so the resolver doesn't tie — see §8).

Aliases finalized at implementation; each must avoid `UNSUPPORTED_TERMS` substrings and be mutually unambiguous (resolver refuses ties).

---

## 6. Quirks — replicate bug-for-bug, disclose via registry

All three are documented in the automation and surfaced automatically by `ask.py`'s footer from `SECTIONS[...]["quirks"]`:
1. **"Supervisor Assigned" ← `SUPERVISOR_ACCEPTED_TS_IST`** (not the separate `SUPERVISOR_ASSIGNED_TS_IST`). Affects metrics 1–2.
2. **"…→ Shifting Complete" ← `PICKUP_COMPLETED_TS_IST → ORDER_COMPLETED_TS_IST`** (no "shifting complete" ts exists). Metric 5.
3. **Location adoption duplicated** under two names (`location_adoption_pct`, `pct_orders_location_modified`), same expression. order_edits.

---

## 7. Wiring — the 4 places a section must appear

1. **`metrics_registry.SECTIONS`** — flip `built:True`, set `readiness:"prototype_only"`, fill `month_basis`, `base_population` ("completed non-Nano intra-city orders"), `quirks` (§6), `verify_flags` (schema-drift note; the "vendor"/p50 NL-exclusion note), `evidence` (D8 supersession note).
2. **`metrics_registry.METRICS`** — one entry per output column (`source:"sql"`, id = column alias), with `unit`, `definition`, `aliases` — **all reachable via `--metric`**. NL-exposure is *emergent*: a metric is NL-queryable only if its natural phrasing avoids `UNSUPPORTED_TERMS` and its aliases resolve unambiguously. So `p50_trip_duration` and `p80_vendor_accepted_to_sup_assigned` still get entries (for `--metric`), but the guard keeps them off NL.
3. **`sqlgen.py`** — add `p80_sql(month)` and `order_edits_sql(month)` builders (§4) + register both in `SECTION_SQL`. Each returns a `WITH`/`SELECT` that passes `assert_read_only` and substitutes the month literal.
4. **`run_tests.py`** — add `PROD_ELDORIA.MART.PNM_EXPERIENCE` to `EXPECTED_TABLES` (the allow-list, enforced only here); add `ANSWERABLE` cases (one per NL metric) + `REFUSALS` (e.g. "median trip duration", "p90…", "trip duration by vendor"); **update the existing `metric_not_built` refusal** that hard-codes `SECTIONS["p80_durations"]["built"] == False` — it will break once we flip `built:True`.

`ask.py` needs **no** change for standard sections.

---

## 8. Known collisions with the closed-world resolver (design-time findings)

- **"vendor" guard vs metric name.** `UNSUPPORTED_TERMS` blocks bare `vendor` (to refuse per-vendor cuts); this collides with `p80_vendor_accepted_to_sup_assigned`. **Decision:** keep the guard; expose that metric via `--metric` only; disclose. (Alternative, deferred: refine the guard to `by vendor`/`per vendor`/`vendor wise` so the stage metric can go NL — a change to existing behaviour, owner call.)
- **p50/median guard** — as D10.
- **Duplicate-location tie risk** — give the two location metrics distinct, non-overlapping aliases; accept that some ambiguous phrasings refuse (safe default).

---

## 9. Verification plan (layered — "tests pass" is not sufficient)

1. **Live schema pre-flight** (§3) — gate.
2. **Dry-run harness** — `python3.12 run_tests.py` green: NL resolution for every new NL metric, refusals, `assert_read_only`, month-literal substitution, table allow-list (now incl. `PNM_EXPERIENCE`). Add an explicit "`month` column present" assertion for the new sections (the current harness only checks the month *literal*, not an `AS month` column).
3. **Differential reconciliation (live, the V3 method)** — for a target month, run the selfserve SQL **and** the automation's query (via Snowflake MCP, read-only), match the automation's row for that month, assert **field-by-field exact equality** on all shared metric columns (both sides `ROUND` identically → bit-identical).
4. **Baseline reconciliation (p80 only)** — compare vs `reference/p80_durations_baseline_2025-10_to_2026-05.csv`. Live-vs-automation is exact; vs the historical CSV use the README's **±2.5%** drift rule (the mart may have been backfilled since the CSV was cut).
5. **Property / adversarial checks** — p80 durations ≥ 0; **`p50_trip_duration` ≤ `p80_trip_duration`** (same window); all order_edits % in `[0,100]`; `edits_per_order` ≥ 0; `location_adoption_pct == pct_orders_location_modified` (duplicate invariant); zero-edit month → `pct_orders_edited = 0` (not null) but `pct_edits_after_shifting_started = NULL` (NULLIF on the edits denominator) — assert this mirrors the automation.
6. **Cross-month stability** — p80 across the 8 baseline months; order_edits across ≥3 live months; trends continuous (no discontinuities).
7. **Checker re-review** — a fresh subagent attacks the diff (schema drift, cross-DB role access, nano symmetry, month-grain, guard collisions) before "done" is claimed.

---

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `PNM_EXPERIENCE` schema drift (mart under construction) | §3 live pre-flight; re-verify at reconciliation; verify_flag disclosed. |
| Snowflake role can't read `PROD_ELDORIA.MART` | Confirm during pre-flight (a `LIMIT 0` succeeds); if blocked, surface to owner. |
| Reconciliation mismatch | It's a *finding*, not a failure — divergence = bug; debug the adaptation, never "adjust to match". |
| `metric_not_built` test breaks on `built:True` | §7.4 — update that refusal in the same change. |
| Contradicts in-repo docs | D8/D9 recorded in DECISION_LOG; iteration-1/2 notes annotated as superseded (not deleted). |

---

## 11. Orchestration method (lightweight, as chosen)

Single orchestrator (me) = the only synthesizer. Read-only **explorers** already mapped the automation + extension points (this spec). A **Checker** subagent runs at step 9.7 (and may re-review the spec now if owner wants). No `Workflow`-tool heavy fan-out; no researcher agents (deferred). Subagents report; the orchestrator decides and holds the single source of truth (this spec + DECISION_LOG).

---

## 12. Open items for the owner (not blocking the build)

- **Sample-size companion:** emit `total_orders` (and a p80 row count) as a trailing, clearly-labelled non-metric column for footer context? Default: **no** (exact mirror), revisit. Percentile/adoption interpretation benefits from N, but it diverges from the automation's output shape.
- Handoff owner-items 1–3 (multi-month number check, Notion Demand cross-check, readiness promotion) remain owner calls.
- Branch hygiene: cut a fresh branch off the PnM tip (`112c992`) for a clean PnM-only lineage, vs. building on current `claude/ptl-metric-catalog-map` HEAD (which carries PTL commits). Recommend the former.

---

## 13. Definition of done (this iteration)

Both sections `built:True`, `readiness:prototype_only`; `run_tests.py` green; live differential reconciliation **exact** vs the automation for ≥1 month (p80 also vs baseline within ±2.5%); property + cross-month checks pass; Checker sign-off; DECISION_LOG updated (D8–D10, a V4 reconciliation entry); one-line status + specific next decision handed to the owner. **No section promoted to stakeholder-ready** — that stays the owner's call.
