# Iteration 3 — Build `p80_durations` + `order_edits` (design spec)

*Status: APPROVED-DIRECTION, board-reviewed · relocated to `~/dev/selfserve` on 2026-07-19 (DLP-lock escape) · PROTOTYPE-ONLY (only the owner promotes readiness) · Author: Claude (orchestrator).*

This spec turns the `HANDOFF-p80-orderedits-orchestration.md` pointer doc into a concrete, reviewable design. It does **not** re-derive decision history — see `DECISION_LOG.md` (D1–D7, V1–V3) and `HANDOFF.md`.

> **Board review (2026-07-14):** a 3-reviewer board stress-tested this spec; one reviewer completed (via GitHub@`112c992`), two were blocked by the DLP lock. Its 3 material fixes are folded in below and tagged **[board-fix]**. A full A/B re-run is a first step now that files are unlocked.

---

## 1. Goal & scope

Build the two remaining report sections by **mirroring the owner's live-validated MBR automation** (`…/ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py`), then prove them with live differential reconciliation.

**In scope:** `p80_durations` (mirror `TRIP_DURATION_PERCENTILE_QUERY`, 7 metrics) · `order_edits` (mirror `EDIT_ADOPTION_QUERY`, 10 metrics) · extend the dry-run harness · reconcile live vs the automation.

**Out of scope:** `ota` (BLOCKED — no clean source) · industry-practice research (deferred) · formalizing as a skill / opening stakeholder access (owner-only).

---

## 2. Confirmed decisions (proposed DECISION_LOG entries D8–D10)

- **D8 — Source = `PROD_ELDORIA.MART.PNM_EXPERIENCE`** for both sections (mirrors the current validated automation via `config.EXPERIENCE_SOURCE_TABLE`). **Supersedes** the stale in-repo notes pointing p80 at `FACT_PNM_ORDERS` and order_edits at `sr_modifications`. The p80 baseline CSV *is* this automation's output; sourcing elsewhere would diverge from the baseline. Owner-confirmed 2026-07-12.
- **D9 — Metric IDs = the automation's exact output-column names, lowercase** (e.g. `p80_trip_duration`, `pct_orders_edited`). `ask.compute_value` does `row.get(metric_id)` and `execute()` **lowercases every result column** — so ids must be lowercase to match. **[board-fix: casing]** Supersedes the never-built iteration-1 `_mins` names.
- **D10 — `p50_trip_duration` is emitted + reconciled but NOT NL-exposed.** The automation emits it and the baseline has it (needed for exact reconciliation), but the resolver's guard refuses `p50`/`median`. Keep the guard; reach it only via `ask.py --metric`; disclose in a `verify_flag`. Owner-confirmed 2026-07-12.

---

## 3. Pre-flight — live schema verification (**first build step, gates all SQL**)

`PNM_EXPERIENCE` is flagged in-file as "still under active construction" (schema grew between two checks a day apart). Before writing any `sqlgen` SQL, verify (read-only, via Snowflake) that **every** required column exists live **and confirm its type**. If any are missing/renamed, STOP and surface to owner.

Required columns (20):

| Group | Columns |
|---|---|
| Filters / keys | `ORDER_STATUS`, `PACKAGE_NAME`, `SHIFTING_TYPE`, `ORDER_ID` |
| p80 grain + stages | `SHIFTING_TS_IST`, `VENDOR_OWNER_ACCEPTED_TS_IST`, `SUPERVISOR_ACCEPTED_TS_IST`, `TRIP_STARTED_TS_IST`, `SHIFTING_STARTED_TS_IST`, `PICKUP_COMPLETED_TS_IST`, `ORDER_COMPLETED_TS_IST` |
| order_edits grain + flags | `ORDER_CREATED_TS_IST`, `IS_MODIFICATION_DONE`, `NO_OF_SUCCESSFUL_EDITS`, `EDITS_AFTER_SHIFTING`, `HAS_SUPPORT_EDIT`, `HAS_LOCATION_EDIT`, `HAS_ITEMS_EDIT`, `HAS_ADDONS_EDIT`, `HAS_SLOT_EDIT` |

Use `INFORMATION_SCHEMA.COLUMNS` (authoritative, live), not the Data Catalog (which may lag this fast-moving mart).

**[board-fix: NTZ]** Also confirm `SHIFTING_TS_IST` and `ORDER_CREATED_TS_IST` are `TIMESTAMP_NTZ`. If they're `TZ`/`LTZ`, comparing to a naive literal (`'2026-05-01'`) shifts the month boundary by the session offset and breaks exact reconciliation — in that case cast or set the session timezone explicitly.

---

## 4. The mirror SQL (single-month adaptation)

Structure-only adaptation (D7): the automation's open-ended `>= start_date` + `GROUP BY month` becomes a single month via a **prunable range** (`ts >= '{month_start}' AND ts < DATEADD('month', 1, DATE '{month_start}')`) — honours micro-partition pruning *and* reconciles to exactly the automation's month row. Every section emits `DATE '{month_start}' AS month` as column 1. No IST shift — columns are already `_TS_IST`.

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
Note: **#10 (`pct_edits_after_shifting_started`) divides by `no_of_successful_edits`**, all other % by `total_orders`. Intermediate counts are not emitted (exact mirror; sample-size companion = NO per owner).

---

## 5. Metric catalog

**`p80_durations`** (`readiness: prototype_only`, `month_basis: SHIFTING_TS_IST`, unit: minutes). All ids **lowercase**.

| metric_id (= column) | NL-exposed? | Notes |
|---|---|---|
| `p80_vendor_accepted_to_sup_assigned` | **No** (`--metric` only) | Name contains "vendor" → hits `UNSUPPORTED_TERMS` (see §8). |
| `p80_sup_assigned_to_trip_started` | Yes | quirk: "Supervisor Assigned" reads `SUPERVISOR_ACCEPTED_TS_IST`. |
| `p80_trip_started_to_shifting_started` | Yes | |
| `p80_shifting_started_to_pickup_complete` | Yes | |
| `p80_pickup_complete_to_order_complete` | Yes | label quirk: "…→ Shifting Complete". |
| `p50_trip_duration` | **No** (`--metric` only) | D10 — p50 guard. |
| `p80_trip_duration` | Yes | Shifting Started → Order Completed. |

**`order_edits`** (`readiness: prototype_only`, `month_basis: ORDER_CREATED_TS_IST`): all 10 NL-exposed. `location_adoption_pct` and `pct_orders_location_modified` are the **duplicate-by-design** pair (identical value; distinct aliases required so the resolver doesn't tie).

Aliases finalized at implementation; each must avoid `UNSUPPORTED_TERMS` substrings and be mutually unambiguous.

---

## 6. Quirks — replicate bug-for-bug, disclose via registry

Surfaced automatically by `ask.py`'s footer from `SECTIONS[...]["quirks"]`:
1. **"Supervisor Assigned" ← `SUPERVISOR_ACCEPTED_TS_IST`** (not `SUPERVISOR_ASSIGNED_TS_IST`). Metrics 1–2.
2. **"…→ Shifting Complete" ← `PICKUP_COMPLETED_TS_IST → ORDER_COMPLETED_TS_IST`**. Metric 5.
3. **Location adoption duplicated** under two names, same expression. order_edits.

---

## 7. Wiring — the 4 places a section must appear

1. **`metrics_registry.SECTIONS`** — flip `built:True`, set `readiness:"prototype_only"`, fill `month_basis`, `base_population`, `quirks`, `verify_flags` (schema-drift; vendor/p50 NL-exclusion), `evidence` (D8 supersession). **[board-fix]** The existing `p80_durations` stub's `month_basis` reads `"o_completed_ts"` — **correct it to `SHIFTING_TS_IST`** (else the footer shows wrong provenance).
2. **`metrics_registry.METRICS`** — one entry per output column (`source:"sql"`, id = **lowercase** column alias), with `unit`, `definition`, `aliases` — all reachable via `--metric`. NL-exposure is *emergent*: NL-queryable only if the natural phrasing avoids `UNSUPPORTED_TERMS` and aliases resolve unambiguously. `p50_trip_duration` and `p80_vendor_accepted_to_sup_assigned` get entries but the guard keeps them off NL.
3. **`sqlgen.py`** — add `p80_sql(month)` and `order_edits_sql(month)` (§4) + register in `SECTION_SQL`; each passes `assert_read_only`.
4. **`run_tests.py`** — add `PROD_ELDORIA.MART.PNM_EXPERIENCE` to `EXPECTED_TABLES` (allow-list, enforced only here); add `ANSWERABLE` cases (one per NL metric) + `REFUSALS` ("median trip duration", "p90…", "trip duration by vendor"); **update the existing `metric_not_built` refusal** that hard-codes `SECTIONS["p80_durations"]["built"] == False` — it breaks when we flip `built:True`.

`ask.py` needs no change.

---

## 8. Known collisions with the closed-world resolver

- **"vendor" guard vs metric name** — `UNSUPPORTED_TERMS` blocks bare `vendor`; collides with `p80_vendor_accepted_to_sup_assigned`. Decision: keep guard; expose that metric via `--metric` only; disclose. (If reviewer C's read of the guard using phrases like `"by vendor"` rather than bare `"vendor"` holds, this metric may be NL-safe after all — **verify the live `UNSUPPORTED_TERMS` list at build**.)
- **p50/median guard** — D10.
- **Duplicate-location tie risk** — give the two location metrics distinct, non-overlapping aliases.

---

## 9. Verification plan (layered)

1. **Live schema pre-flight** (§3) — gate.
2. **Dry-run harness** — `python3.12 run_tests.py` green: NL resolution per new NL metric, refusals, `assert_read_only`, month-literal substitution, allow-list (incl. `PNM_EXPERIENCE`). Add an explicit "`month` column present" assertion for the new sections (current harness checks the month *literal*, not an `AS month` column).
3. **Differential reconciliation (live, V3 method)** — run selfserve SQL + the automation's query (Snowflake, read-only) for a month; match the automation's row; assert **field-by-field exact equality** (both `ROUND` identically → bit-identical).
4. **Baseline reconciliation (p80)** — vs `reference/p80_durations_baseline_2025-10_to_2026-05.csv`. Live-vs-automation exact; vs historical CSV use README's **±2.5%** drift rule.
5. **Property / adversarial** — durations ≥ 0; **`p50_trip_duration` ≤ `p80_trip_duration`**; all order_edits % in `[0,100]`; `location_adoption_pct == pct_orders_location_modified`; zero-edit month → `pct_orders_edited = 0` but `pct_edits_after_shifting_started = NULL` (mirror the automation's NULLIF).
6. **Cross-month stability** — p80 across the 8 baseline months; order_edits ≥3 live months.
7. **Checker re-review** — fresh subagent attacks the diff before "done".

---

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| `PNM_EXPERIENCE` schema/type drift | §3 live pre-flight incl. NTZ types; re-verify at reconciliation. |
| Snowflake role can't read `PROD_ELDORIA.MART` | Confirm at pre-flight (`LIMIT 0`). Note: `MART.PNM_CUSTOMERS` is already read by built sections, so MART is not a new grant. |
| Reconciliation mismatch | A *finding*, not a failure — divergence = bug; never adjust to match. |
| `metric_not_built` test breaks on `built:True` | §7.4 — update in the same change. |
| Contradicts in-repo docs | D8–D10 recorded in DECISION_LOG; iteration-1/2 notes annotated as superseded. |

---

## 11. Orchestration method (lightweight)

Single orchestrator = the only synthesizer. Read-only explorers mapped the automation + extension points. A **maker–checker board** reviews the spec (partial pass done 2026-07-14; re-run A/B now unlocked) and a **Checker** subagent runs at 9.7. No `Workflow`-tool heavy fan-out; no researcher agents (deferred).

---

## 12. Owner decisions (resolved 2026-07-14)

- **Sample-size companion:** ❌ No. Exact mirror only.
- **Branch hygiene:** ✅ Fresh branch off `112c992` — done: `claude/pnm-p80-orderedits` in `~/dev/selfserve` (repo relocated out of the DLP-locked `~/Desktop/AI_V2` tree on 2026-07-19).
- **Handoff owner-items 1–3** (multi-month check, Notion cross-check, readiness promotion): deferred — evaluate later.

---

## 13. Definition of done

Both sections `built:True`, `readiness:prototype_only`; `run_tests.py` green; live differential reconciliation **exact** vs the automation for ≥1 month (p80 also vs baseline within ±2.5%); property + cross-month checks pass; Checker sign-off; DECISION_LOG updated (D8–D10 + a V4 entry); one-line status + next decision to the owner. **No stakeholder promotion** — owner's call.
