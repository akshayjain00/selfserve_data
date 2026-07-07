# PnM Self-Serve — Iteration 2: Prototype + Readiness Ledger

*Prepared 2026-07-07. Prototype in `pnm-selfserve/selfserve_nlq/` (new subfolder; the 5
original files remain untouched). Approved architecture implemented as specified: closed-world
registry + deterministic read-only CLI (dry-run default) + Claude-in-session NL resolution,
bug-for-bug fidelity with quirks disclosed.*

---

## 1. What was built

| File | Role |
|---|---|
| `metrics_registry.py` | The menu: 25 queryable metrics across leads / orders / derived / tpo, with definitions, verbatim ⚠ VERIFY flags, quirks, evidence, section readiness. Plus a deterministic alias resolver that refuses unsupported dimensions/grains. |
| `sqlgen.py` | One read-only SELECT per section; staging logic inlined as CTEs (3 documented adaptations: no CREATE, staging-table reference → inline CTE, broken named-colon binds → validated literals). `assert_read_only` guard. |
| `ask.py` | CLI. Dry-run default (prints exact SQL + trust footer, executes nothing). `--execute` runs the single SELECT via SF_* env vars; every executed answer appended to `answers_log/answers.jsonl`. |
| `run_tests.py` | 24 answerable questions + 7 refusal cases; writes `tests_output/dry_run_report.md` + one rendered SQL per section for owner review. |

Sections: **leads, orders, derived, tpo built** (TPO included as required — it is the most
complex). **ota blocked** (structurally unrunnable), **p80_durations / order_edits not built**
(iteration 3). No new dependencies: dry-run is stdlib-only; `--execute` lazily imports
`snowflake-connector-python` (already a pipeline dependency). No pandas needed.

## 2. Test results (dry-run round)

**31 / 31 pass** — full detail in `selfserve_nlq/tests_output/dry_run_report.md`, rendered SQL
in `tests_output/rendered_*_2026-05.sql`. What the suite verifies: every question resolves to
the intended metric (or refuses), every rendered SQL passes the read-only guard, both window
months are substituted, only expected tables are referenced, the physical staging schema is
never touched, and MTD labeling fires exactly for the in-progress month (July 2026).

The first run caught 2 real failures, both fixed and re-tested:
1. "orders in the TPO base" resolved to `orders_overall` instead of `orders_base` (alias gap).
2. "City-wise leads in Bangalore?" wrongly resolved to `leads_overall` — fixed with an
   unsupported-dimension guard: the resolver now refuses city/vendor/weekly/daily/median
   questions outright instead of silently answering the PnM-wide monthly number.

**What this round could NOT test: actual numbers.** This environment has no Snowflake
credentials. Numeric validation = the execution round, pending your go-ahead (§5).

## 3. New evidence on the ⚠ VERIFY flags (metadata only — no data queried)

Gathered from the Data Catalog and Metabase card metadata via the connectors you enabled.
Per the standing rule, nothing was resolved — each item is an input to YOUR decision:

| Flag | Evidence | Status |
|---|---|---|
| `tickets` table name (⚠ TPO) | **No `pnm_application.tickets` exists.** `prod_curated.sfms_public.hs_tickets` is the PnM tickets table: `raised_by` values (Customer/Vendor-Owner/Vendor-Supervisor/Porter Support/**Detractor**/Chat) match the query's filters exactly. | Guess almost certainly wrong — decision needed |
| `order_status_at_creation` (⚠ TPO) | hs_tickets has `order_status_when_ticket_created` (same intent, different name); status values match the query's buckets (open, supervisor_assigned, …, cancelled). | Column name wrong — decision needed |
| TPO join key | hs_tickets has **no `order_id`** — links to orders via `crn` / `hs_order_id`. | Join as written will fail — decision needed |
| `order_allocation_infos` | Exists in `pnm_application` exactly as guessed. | Confirmed ✓ |
| OTA columns (⚠ OTA) | No `scheduled_pickup_ts` / `vendor_arrived_ts` column exists in any catalogued table (212 near-matches checked). | Columns don't exist — OTA needs a real data-source decision |
| `order_modifications` (⚠ order_edits, iteration 3) | Not found; `pnm_application.sr_modifications` matches the four flagged categories but is keyed on SR, not order. | Likely wrong table — decision needed in iteration 3 |
| `fact_pnm_opprotunity` typo | The typo'd name is what config points at in `pnm_application` (existence there unconfirmed via catalog); **`PROD_ELDORIA.core.fact_pnm_opportunity` exists as a dbt model owned by NI_PNM, with a semantic model already generated.** | Verify at execution |
| Methodology (card #30311) | The card is `[DBT] Conversion %` and reads `prod_eldoria.core/mart` dbt models, NOT `pnm_application`. It excludes Nano everywhere, uses `service_type IN ('Default','Default_Short')` for intra-city, joins customers on `customer_mobile`, and has no status filter / no first-order-per-SR dedup. | Script diverges from its own stated methodology — decision needed |

## 4. Readiness ledger (iteration 2)

Per the standing rule: open flag or unvalidated answer ⇒ NOT ready. No section can be READY
FOR STAKEHOLDERS before the execution round validates real numbers, so today's ledger is:

| Section | Classification | Why | What promotion requires |
|---|---|---|---|
| **leads** | PROTOTYPE-ONLY | No section ⚠ flag, but: config-wide "verify before first run" is unresolved, the fact table name is typo'd/unconfirmed in `pnm_application`, numbers never validated live, and the script diverges from card #30311 (Nano handling). | Successful execution round + your ruling on the Nano/card-30311 divergence + drift-check vs the MBR sheet values. |
| **orders** | PROTOTYPE-ONLY | Same as leads, plus undocumented status codes and the attribution-window quirk. | Same as leads + confirm `status`-code semantics. |
| **derived** (conversion, order mix) | PROTOTYPE-ONLY | Inherits leads + orders; card #30311 computes conversion differently (Nano excluded). | Both parents ready + your divergence ruling. |
| **tpo** | PROTOTYPE-ONLY (execution will fail as written) | Open ⚠ flags now have hard evidence against the guessed table/column/join. Bug-for-bug SQL cannot return numbers until you decide: keep as-is (fails, stays theoretical) or approve the hs_tickets adaptation (table + column rename + crn join) as an explicit definition change. | Your decision on the hs_tickets adaptation → rebuild → execution round → validate vs any known TPO baseline. |
| **ota** | BLOCKED | Unrunnable as written; flagged columns don't exist anywhere. Needs a data-source decision (e.g. supervisor_actions GPS events), which is a definition, not a bug fix. | Owner defines the OTA source → build in iteration 3. |
| **p80_durations** | NOT BUILT (iteration 3) | Timestamps all live on the confirmed `orders` table, so this is the cleanest remaining candidate. | Build + execution round. |
| **order_edits** | NOT BUILT (iteration 3) | Flagged table likely wrong (`sr_modifications` evidence). | Owner ruling on source table → build. |

**Nothing is READY FOR STAKEHOLDERS yet.** That is the honest state: the pipeline these
definitions come from has plausibly never completed a real run (named-colon binds + "verify
before first run" comment), so there is no validated baseline anywhere yet — this prototype's
execution round would BE the first validation.

## 5. The execution round (needs your explicit go-ahead)

Per the standing rule, no production Snowflake touch without you seeing the exact SQL first.
The four queries that would run (one per section, May 2026; other months are the same SQL with
different literals) are committed for review at:

```
pnm-selfserve/selfserve_nlq/tests_output/rendered_leads_2026-05.sql
pnm-selfserve/selfserve_nlq/tests_output/rendered_orders_2026-05.sql
pnm-selfserve/selfserve_nlq/tests_output/rendered_derived_2026-05.sql
pnm-selfserve/selfserve_nlq/tests_output/rendered_tpo_2026-05.sql     ← will fail as written (see §3)
```

All are single read-only SELECTs against `PROD_CURATED.pnm_application` (+ `tickets`, which
doesn't exist — TPO's failure is itself a test result). Two execution paths:

- **Path A — your laptop:** `python ask.py --metric <id> --month <YYYY-MM> --execute` with the
  same SF_* env vars the pipeline uses. Nothing else needed.
- **Path B — this session via the Metabase connector** (`execute_query` against database 108,
  the same database card #30311 uses): I paste exactly the committed SQL, you approve each run.
  Caveat: it runs under your Metabase account's permissions.

## 6. Argus rules vs. value — choices this iteration surfaced (per your new standing instruction)

1. **"No dbt model → not eligible for the metric store" may be moot for PnM sooner than
   planned.** PROD_ELDORIA already has an NI_PNM-owned dbt layer (fact/dim opportunity, orders,
   vendor, mart.pnm_customers, mart.pnm_support/experience/allocation/base_query) with semantic
   models generated. Choice: (a) keep the prototype bug-for-bug on `pnm_application` raw tables
   (reconciles with the current sheet), or (b) re-point sections to the eldoria models —
   a definition change, but it aligns with card #30311 and makes Argus onboarding mostly
   paperwork. My read: (a) for iteration 3 validation, (b) as the formalization path — but it's
   your call, not mine.
2. **The "governed or refuse" instinct vs. analyst speed.** This prototype refuses anything
   off-menu. If that friction blocks real usage, the rule we could deliberately relax is
   answering off-catalog questions with an explicit LOW-CONFIDENCE banner instead of refusing —
   Argus itself refuses below 50%. Not recommended yet; flagging it as a choice you own.

---

**Status:** Iteration 2 complete — 4-section prototype built and dry-run-tested (31/31), flag
evidence gathered, ledger delivered; everything is PROTOTYPE-ONLY or BLOCKED pending the
execution round.

**Decisions needed:** (1) approve the execution round — Path A (your laptop) or Path B
(Metabase connector, per-query approval); (2) rule on the TPO adaptation: keep the guessed
`pnm_application.tickets` (fails) or adopt `sfms_public.hs_tickets` + `crn` join +
`order_status_when_ticket_created` as an explicit definition change; (3) still need
`gsheet_client.py` uploaded for the drift-check work in iteration 3.

---

## Post-review update (2026-07-07, owner decisions applied)

- **Decision 1 → Path A** (execution on owner's laptop via `ask.py --execute`). No production
  Snowflake touch from this session.
- **Decision 2 → TPO adaptation APPROVED and applied** (`sfms_public.hs_tickets` + `crn` join +
  `order_status_when_ticket_created`). Committed in `sqlgen.py`; the original ⚠ VERIFY flag is
  kept verbatim in the registry, now marked addressed-pending-execution. Confidence in the
  adaptation was ~90% from Data Catalog evidence.
- **Decision 3 → `gsheet_client.py` received and read.** Lock behavior confirmed exactly as
  assumed: current MTD month row overwritten in place; completed months appended once then never
  touched (`upsert_results`). No change to the prototype needed; iteration 3 drift/sanity checks
  can rely on this.
- **NEW cross-cutting blocker surfaced during decision-2 work (~95% confidence):** the orders
  staging reads `order_id` and the lifecycle timestamps from the raw `pnm_application.orders`
  table, but Data Catalog + the `core.fact_pnm_orders` compiled dbt SQL show those columns don't
  exist there — they're assembled in the eldoria core model. This means leads/orders/derived/tpo
  cannot execute against the configured raw tables at all. See `metrics_registry.ORDERS_SOURCE_DECISION`
  and `HANDOFF.md` §"Open decision: orders source". This makes re-pointing to the eldoria dbt
  models the recommended path (~85%) — and it happens to unblock Argus eligibility.
- Owner also set a **global rule going forward: present choices with a % confidence.** Applied in
  `ORDERS_SOURCE_DECISION` and `HANDOFF.md`.

Continuation happens in a new Claude Code terminal — see **`HANDOFF.md`** at the repo root of
`pnm-selfserve/`.
