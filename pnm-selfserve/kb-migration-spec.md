# kb-migration-spec.md — standing up `pnm-selfserve/kb/` on the PTL architecture

*Phase B deliverable. Written 2026-08-25. Author: Claude Code (orchestrator).
**Status: AWAITING OWNER APPROVAL. No file under `pnm-selfserve/kb/` has been created.***

> **What this is.** PTL has a row-addressed knowledge base (`ptl-selfserve/kb/`, 9 files) where every
> fact carries an ID, a source you can open, and a confidence label. PnM has none — its facts live as
> narrative across five documents plus a Python registry. This spec evaluates what transfers, what
> must legitimately diverge, and exactly what would be built.
>
> **The headline.** PnM cannot copy PTL's architecture. PTL's ladder is topped by observed Metabase
> card SQL; PnM's canonical card (**#30311**) is **ruled non-authoritative by its own owner** (D6),
> and PnM's strongest evidence — the live-validated MBR automation — **is not in this repo and can
> never be cited above `unverified`**. Four of PTL's nine files port cleanly, two must change shape,
> and one must not be ported at all.

---

## Part 0 — Method and constraints honoured

- Read in full: the 9 PTL `kb/` files, `ptl-selfserve/DECISION_LOG.md`, `ptl-selfserve/coordination/DECISIONS.md`, and the 10 PnM files named in the brief.
- **No existing file was modified, moved or deleted, and `pnm-selfserve/kb/` was not created.** The single write this session is **this file**, which is therefore new and untracked. No Metabase, Snowflake or Data Catalog query was run. Beyond this file, `git status` is unchanged from session start — including one pre-existing modification I did **not** touch (§7.1).
- Every SHA proposed as a `source_ref` below was verified byte-identical to the working tree via `git show <sha>:<path> | cmp` before being written here.

---

# Part 1 — Architecture-gap evaluation

## 1.1 Which PTL shelf each existing PnM fact belongs on

| PTL shelf | PnM material that lands there | Volume |
|---|---|---|
| `business.md` (`B-`) | Nano/LA attribution rule (D4); readiness ladder (`prototype_only`/`stakeholder_ready`/`blocked`/`not_built`); owner-only promotion; dry-run default (D1); closed-world refusal; aggregate-then-ratio; NULLIF→NULL; MTD labelling; the "% confidence on every choice" house rule; "never silently resolve a ⚠ VERIFY"; Argus eligibility rule; glossary (PnM, MBR, TPO, OTA, P80, SR, CRN, LA, Nano, LMS, opportunity/lead, intra-city, normal user, detractor); V3's reconciled 2026-05 values as a **labelled snapshot** | ~34 rows |
| `metrics.md` (`M-`) | The 30 live registry metrics across 4 built sections; the 3 not-built sections (ota 3, p80 6-or-7, order_edits 10) as index rows; a pointer to the 167-row Argus DD | 11 blocks covering 30 ids, + 2 index tables |
| `data-model.md` (`T-`) | 11 tables across 4 schemas; join keys (`customer_mobile`, `sr_id`, `opp_id`, `order_id`, `crn`, `a.id = b.order_id`); enums (`raised_by`, `order_status_when_ticket_created`, `shifting_type`, `user_flag`, `source`/`source_details`, legacy `status`); units; IST `+330 min` time basis; segmentation/exclusion predicates; privacy columns | ~32 rows |
| `dashboards.md` | **Weak counterpart.** Only 2 Metabase cards exist (#30311, #47576), one of them demoted by ruling, and neither can be fingerprinted offline. → becomes `sources.md` (`S-`), §2.3 | ~11 rows |
| `GAPS.md` (`G-`) | Every conflict in §1.4, every unsourceable claim in §1.3, plus coverage gaps | ~57 rows |
| `query-rules.md` (`Q-`) | **Nothing.** §2.4 — not ported, with reasoning | 0 |
| `CONTEXT.md` | Ported | ≤175 lines |
| `CONTRIBUTING.md` | Ported, amended for PnM's ladder + ID namespace | — |
| `SOP.md`, `WALKTHROUGH.md` | Deferred, §2.4 | 0 |
| sibling `../DECISION_LOG.md` | **Already exists** at `pnm-selfserve/DECISION_LOG.md` (D1–D7, V1–V3). Referenced as a sibling exactly as PTL does. Not created, not modified. | — |
| sibling `../coordination/` | **Does not exist for PnM** and is out of scope (writes are confined to `kb/`). PnM's ladder must not depend on it. | — |
| sibling `../coverage-map/` | Exists. Read-only input; **never edited**, per the brief and SOP §2. | — |

## 1.2 Where PnM must legitimately DIVERGE from PTL

SOP §10 names one divergence. Here are **five**, of which four were found in this pass.

### D-1 (named in SOP §10) — the top rung is the validated MBR automation, not card SQL
Confirmed, and the reason is stronger than SOP §10 states. It is not merely that PnM's automation is good; it is that PnM's **canonical card is ruled wrong**. `config.py`'s own header declares *"Canonical methodology: Metabase card #30311"*, and D6 overrides it: #30311 strips Nano from the entire funnel, which contradicts owner ruling D4. In PTL, a card outranks a document. In PnM, a card lost to an owner ruling on its first contact with one.

### D-2 (new) — rungs 1 and 2 are INVERTED relative to PTL
PTL puts observed SQL **above** owner rulings, and makes "SQL vs ruling → do not resolve" its absolute exception. PnM must put the **owner ruling above the SQL**, because PnM's load-bearing facts are *business-attribution* decisions that no query can yield. D4 — "Nano is labour-only help owned by LA; include it in leads, exclude it from orders and TPO" — is not discoverable in any table; it is a statement about which business unit owns a booking. PTL's disputes are *"what does this number compute?"* (SQL settles it); PnM's are *"whose population is this?"* (only the owner settles it).

**The absolute exception is preserved, with its pair swapped:** where the validated automation's SQL contradicts an owner ruling, record both sides, set `confidence: unverified`, open a `PNM-G-###`. Do not pick a side.

### D-3 (new) — PnM's strongest evidence is structurally uncitable
The MBR automation (`.../ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py`) is **not in this repo**. Under CONTRIBUTING §3 it can only ever be cited `local:`, and a `local:`-only fact "can never be more than `unverified`". So PnM's top evidentiary rung cannot itself produce a single `verified` row.

**The resolution, and it is what makes this KB possible:** `sqlgen.py` is the automation's **in-repo mirror**, and V3 proved the mirror exact for 2026-05. So PnM's `verified` rows cite `repo@112c992:pnm-selfserve/selfserve_nlq/sqlgen.py`, with the automation riding as `local:` corroboration. This is a materially different provenance chain from PTL's and must be stated in `CONTRIBUTING.md`, not left implicit.

⚠ **The chain's honest limit:** V3 reconciled **one month (2026-05)** and **14 of 30** metric ids, across **7 comparison rows** (three of those rows are multi-metric composites). Everything outside that slice is extrapolation → `PNM-G-004`.

### D-4 (new) — the staleness mechanic does not transfer
PTL detects drift with one `get_card` metadata call comparing `updated_at` to a recorded `source_updated_at`. **PnM has almost no source that carries such a stamp:**

| PnM source type | Has an `updated_at`? | PnM's freshness check instead |
|---|---|---|
| In-repo file at a SHA | No — but a SHA cannot drift | Re-read at the SHA. Free, deterministic, offline. |
| MBR automation (out-of-repo `.py`) | Not readable offline | **Gap** — needs the owner to place it under version control or stamp it (`PNM-G-006`) |
| `PROD_ELDORIA.MART.PNM_EXPERIENCE` | Schema drifts silently — iteration-3 §3 records it "grew between two verifications a day apart" | `INFORMATION_SCHEMA.COLUMNS` pre-flight — **live, needs owner go-ahead** (`PNM-G-007`) |
| Metabase cards #30311 / #47576 | Yes | PTL's mechanic works — but is **unavailable to this offline pass** (`PNM-G-008`) |
| **Untracked repo files** (iteration-3 spec, coverage-map) | No SHA at all | **Cannot be fingerprinted** (`PNM-G-002`) |

Consequence: `source_updated_at` is **absent** from most PnM tables (CONTRIBUTING §2 permits this — "only when the source has one"), and PnM's staleness section documents a *different* check.

### D-5 (new) — PnM carries a `readiness` axis PTL does not have
Every PnM section carries `readiness ∈ {prototype_only, stakeholder_ready, blocked, not_built}`, promoted **by the owner only**. This is **orthogonal to `confidence`** and neither substitutes for the other: `orders_base` is `verified` (its SQL was read) *and* `prototype_only` (not stakeholder-safe). PTL has no such concept. Dropping it would delete the single most operationally important fact about every PnM metric — a reader would quote a number the owner has never cleared.

**Proposal:** `readiness` is a **`metrics.md`-only** column. `CONTRIBUTING.md` states explicitly that it never substitutes for `confidence` and that only the owner changes it.

### Divergences deliberately NOT taken
- **The row schema itself** — `id` / `statement` / `source_ref` / `confidence` is kept exactly. It is the contract.
- **Confidence vocabulary** — `verified` / `unverified` / `assumption`, graded per CONTRIBUTING §4, unchanged.
- **Append-only IDs, closed-not-deleted gaps, correct-the-row-not-the-pointer** — all kept.

## 1.3 Facts encoded ONLY in `metrics_registry.py` / `sqlgen.py` with no document behind them

The brief asks for these specifically. Reading a fact **out of code** clears CONTRIBUTING §4's `verified` bar for *"this is what the prototype computes"*. What follows is a different category: **behaviour the code enacts that no document explains or ratifies.** Each becomes a gap, not a verified definition row.

| # | Registry/sqlgen-only behaviour | Why it is a gap, not a fact | Gap |
|---|---|---|---|
| 1 | Channel `CASE` falls through `ELSE 'Mobile Website'` — unknown/null `source` silently becomes Mobile Website | Materially inflates `leads_mobile` / `orders_mobile` and depresses `conversion_mobile`. No document justifies Mobile Website over an `Unknown` bucket | `PNM-G-011` |
| 2 | Orders Nano filter is `(package_name NOT ILIKE 'Nano%' OR package_name IS NULL)` — **null-package orders are kept as non-Nano** | D4 rules on Nano; it is silent on nulls. The `IS NULL` branch is an unratified population decision | `PNM-G-012` |
| 3 | Dedup tiebreak `ORDER BY fpo.opp_id DESC NULLS LAST` | Registry calls it "deterministic". Deterministic ≠ correct — nothing says the highest `opp_id` is the right opportunity | `PNM-G-013` |
| 4 | TPO tickets filter `COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'` | A two-source fallback chain described in no document; changes which tickets count when `hs_tickets.shifting_type` is null | `PNM-G-014` |
| 5 | Detractor exclusion is `COALESCE(raised_by,'') != 'Detractor'` (exact) | iteration-1 records the pipeline's filter as `LOWER(raised_by) LIKE '%detractor%'`. A value like `Detractor-Customer` is **excluded by one and kept by the other** | `PNM-G-015` *(also a conflict, C6)* |
| 6 | TPO ratios `ROUND(…, 4)`; V3 compares against the automation's 2dp and asserts "rounds identically" | An unproven precision claim at the reconciliation boundary | `PNM-G-016` |
| 7 | `UNSUPPORTED_TERMS` hardcodes 40 terms incl. 15 city names; comment sources them to "card #30311 pickers" | The list governs every refusal. Its provenance is a code comment, unverifiable offline; a city absent from it would be silently answered PnM-wide | `PNM-G-017` |
| 8 | `conversion_others` **does not exist**, though `leads_others` and `orders_others` both do | Every other channel has a conversion metric. Absent by design or by omission — nothing says which | `PNM-G-018` |
| 9 | `month_bounds()` still returns `month_start_prev`, "retained for API stability" — no SQL uses it | The dead value is the last trace of the 2-month attribution window. Its removal silently voided iteration-1 §2b#5's entire undercount analysis, which remains unannotated | `PNM-G-019` *(also C7)* |
| 10 | `p80_durations.month_basis = "calendar month of o_completed_ts"` | `o_completed_ts` is a legacy raw-table column D3 established does not exist. DECISION_LOG §4.3 flags it as needing remapping; iteration-3 says `SHIFTING_TS_IST` | `PNM-G-020` *(also C11)* |
| 11 | `ota.base_population = "completed (status=2) …"` | `status` is the legacy numeric column D3 established is absent from the raw table | `PNM-G-021` |
| 12 | `CONFIG_WIDE_FLAGS` still carries *"Canonical methodology: Metabase card #30311"* verbatim as an open flag | D6 ruled #30311 non-authoritative. The flag is stale but is carried as live | `PNM-G-022` *(also C17)* |

## 1.4 Conflicts between PnM documents — recorded, NOT resolved

**Twenty-six.** Every one gets a `PNM-G-###` row stating both sides. None is resolved here.

### Group A — iteration-1 vs the owner rulings that superseded it (10)
D5 states it "corrected **six** things my initial re-point had wrong". Those corrections landed in `sqlgen.py`; **iteration-1 was never annotated**, so a reader who opens it gets six wrong answers with no warning.

| C | Question | iteration-1 (`a0057ba`) says | D4/D5 + `sqlgen.py` (`112c992`) says | Gap |
|---|---|---|---|---|
| C1 | Nano in orders | **INCLUDED** (§orders; §2b#4 "leads, orders, and all derived … include Nano") | **EXCLUDED** (`package_name NOT ILIKE 'Nano%'`) | `PNM-G-030` |
| C2 | Order dedup key | first order per **`sr_id`** | per **`order_id`** | `PNM-G-031` |
| C3 | Cancelled orders | excluded via `status != 4` | **no cancelled filter** — all created orders count | `PNM-G-032` |
| C4 | Intra-city predicate | `service_type IN ('Default','Default_Short')` (via card #30311) | `shifting_type = 'intra_city'` | `PNM-G-033` |
| C5 | TPO denominator unit | distinct **orders** from the staging base | `COUNT(DISTINCT a.crn)` — distinct **CRNs**. crn↔order cardinality is stated nowhere | `PNM-G-034` |
| C5b | TPO ticket join key | tickets joined by **`order_id`** (§tpo) | `LEFT JOIN … ORDERS a ON hst.crn = a.crn` — joined on **`crn`**. iteration-2 §3 separately records that `hs_tickets` has **no `order_id` at all**, so iteration-1's stated join cannot execute | `PNM-G-035` |
| C5c | Vendor-ticket predicate | the IN-list `('Vendor-Owner','Vendor-Supervisor')` | `hst.raised_by ILIKE 'Vendor%'` — a **prefix match**, which admits any future `Vendor-*` value the IN-list would exclude | `PNM-G-036` |
| C5d | TPO same-month attribution | tickets counted **only if created in the same calendar month** as the allocation completion — a row-level filter | two independent CTEs (orders bucketed on `completed_ts`, tickets on `hst.created_at`) joined at `t.month = o.month`. Same aggregate for a single month; **not the row-level mechanism described**, and the tickets CTE is not restricted to the order base at all | `PNM-G-037` |
| C6 | Detractor filter | `LOWER(raised_by) LIKE '%detractor%'` | `COALESCE(raised_by,'') != 'Detractor'` | `PNM-G-015` |
| C7 | Attribution window | every section inherits a **2-month** created-orders staging window ⇒ channel undercount + spillover months (§2b#5) | **single month**, no window | `PNM-G-019` |

### Group B — iteration-3 (DRAFT, untracked) vs iteration-1 / registry / DECISION_LOG (8)

| C | Question | Side A | Side B | Gap |
|---|---|---|---|---|
| C9 | p80 metric ids | `_mins`-suffixed (iteration-1 §p80; `reference/README.md` maps the baseline CSV to these) | automation column names, no `_mins` (iteration-3 **D9**) | `PNM-G-040` |
| C10 | p80 metric count | **6** (iteration-1) | **7** — adds `p50_trip_duration` (iteration-3 §1, §4a) | `PNM-G-041` |
| C11 | p80 month basis | `o_completed_ts` (iteration-1 **and** registry) | `SHIFTING_TS_IST` (iteration-3 §4a) | `PNM-G-020` |
| C12 | p80 / order_edits source table | raw `pnm_application`; `order_modifications` / `sr_modifications` (iteration-1, registry); DECISION_LOG §4.3 says only "will need an eldoria/mart mapping" | `PROD_ELDORIA.MART.PNM_EXPERIENCE` (iteration-3 **D8**) | `PNM-G-042` |
| C14 | order_edits metric membership | includes `total_orders`; names `pct_edit_*_adoption` | **omits** `total_orders` (§4b "not emitted — exact mirror"); adds `pct_orders_location_modified` as a duplicate-by-design of `location_adoption_pct` | `PNM-G-043` |
| C16 | OTA metric count | **3** (`base_orders`, `ota_pct`, `delay_over_60_mins_pct`) | **2** blocked rows in the coverage map | `PNM-G-044` |
| **C13** | **Do D8–D10 exist?** | iteration-3 §2 titles them *"proposed DECISION_LOG entries"*, and **D8 (L27) and D10 (L29) each say "Owner-confirmed 2026-07-12"** | `DECISION_LOG.md` @ `112c992` **stops at D7**. No D8, D9 or D10 anywhere | **`PNM-G-045`** |
| **C13b** | **D9 claims no owner confirmation at all** | **D9 (L28) carries NO "Owner-confirmed" stamp** — its rationale ends *"The `_mins` ids were never built, so this is free to supersede"*, which is an authorial argument, not a ruling | Yet D9 is the decision that **supersedes a committed, tracked artifact** — `reference/README.md` @ `c319c05`, which maps the p80 baseline CSV to the `_mins` ids | **`PNM-G-047`** |

> **C13/C13b are the ones that matter most.** If D8–D10 are owner rulings they sit on **rung 1** and settle C9–C12 and C14 outright. If they are proposals they sit on **rung 7** and settle nothing. iteration-3 asserts both readings in the same section — and **does so unevenly**: two of the three carry an owner stamp and the third does not. **D9 is the weakest of the three and the only one that overrides a committed file**, which is the reverse of the ordering you would want. **Not resolved here** — Open Questions 1 and 1b in §6.

### Group C — document vs document, and document vs code (8)

| C | Conflict | Gap |
|---|---|---|
| C8 | **Metric count.** `HANDOFF.md` §3 and `iteration-2` §1 both say the registry holds **25** metrics. `metrics_registry.METRICS` holds **30** (leads 5 + orders 5 + derived 7 + tpo 13) — **and iteration-1's own section headings sum to the same 30** (§leads 5, §orders 5, §derived 7, §tpo 13). So "25" disagrees with the code *and* with the catalogue it derives from: a stale figure, not code drifting past docs | `PNM-G-050` |
| C24 | **Ambiguous commit citations.** `git log --all` carries **five pairs of commits with identical messages on divergent branches** (`28703aa`/`6912804`, `c7c1d06`/`c0086b1`, `0ab9d92`/`836e78e`, `739d719`/`a5a973a`, `49d1d85`/`5fddacb`). Every SHA cited in §4.1 was byte-verified and is unambiguous, but a future `repo@<sha>` citation written from a message rather than a hash could land on either twin | `PNM-G-055` |
| C17 | **Canonical methodology.** `config.py` header (carried verbatim into the registry's live `CONFIG_WIDE_FLAGS`): *"Canonical methodology: Metabase card #30311."* — D6: reconcile against the MBR note / Notion Demand DB, **NOT** #30311 | `PNM-G-022` |
| C19 | **`fact_pnm_opprotunity` typo.** `config.py` points at the typo'd name; eldoria has the correctly-spelled model; `sqlgen.py` uses the correct spelling — yet iteration-2 §3 still lists it as "verify at execution" and the flag is carried as open | `PNM-G-051` |
| C20 | **Coverage-map vs registry.** The map marks **25** rows `partial`; the registry has **30** metrics; the map's 167 Argus ids have **no stated mapping** to the 30 registry ids (`resolves_to` is `null` on all 167) | `PNM-G-052` |
| C21 | **`docs/overview.html`** (`5608e74`, tracked) still presents *"Open decision: which orders source?"* — D3 resolved it 2026-07-08 | `PNM-G-053` |
| C22 | **Reproducibility.** `dry_run_report.md` is produced by a `today`-dependent function (`is_month_in_progress`), so re-running the suite silently changes the committed artifact. The working tree currently holds an uncommitted 2026-08-14 re-run that dropped the `[MTD-labeled]` markers present in the committed 2026-07-08 version | `PNM-G-054` |
| C23 | **HANDOFF §5 vs iteration-3.** HANDOFF's flag table lists `order_modifications` as *"open — iteration-3 decision"*; iteration-3 D8 claims it decided. Depends entirely on C13 | `PNM-G-046` |

---

# Part 2 — Proposed file list

## 2.1 Files to CREATE (7, all under `pnm-selfserve/kb/`)

| File | Purpose | ID prefix | Est. rows |
|---|---|---|---|
| `CONTEXT.md` | Front desk: load protocol, PnM's precedence ladder, confidence + readiness, hard rules, state of the work. **Hard cap 175 lines**, matching PTL's stated rationale (an over-long entry point stops being read) | — | ≤175 lines |
| `CONTRIBUTING.md` | The law, amended for PnM: the `PNM-` ID namespace (§2.2), PnM's ladder, the `readiness` column, PnM's staleness check (D-4), and the `local:`-ceiling consequence (D-3) | — | — |
| `business.md` | What PnM is, Nano/LA rule, glossary, house conventions, Argus posture, **labelled V3 snapshot** | `PNM-B-###` | ~34 |
| `metrics.md` | 11 metric blocks covering all 30 live registry ids; index table for the 3 not-built sections; pointer to the 167-row Argus DD | `PNM-M-###` | 11 blocks + 2 index tables |
| `data-model.md` | Tables, columns, join keys, enums, units, IST time basis, segmentation/exclusion, privacy | `PNM-T-###` | ~32 |
| `sources.md` | PnM's counterpart to PTL's `dashboards.md` — one row per external source artifact with its freshness state (§2.3) | `PNM-S-###` | ~11 |
| `GAPS.md` | Every conflict in §1.4, every unsourceable claim in §1.3, coverage gaps | `PNM-G-###` | ~57 |

## 2.2 ID namespace

**Convention: `PNM-<series>-###`** — `PNM-B-001`, `PNM-M-001`, `PNM-T-001`, `PNM-S-001`, `PNM-G-001`.

PnM `PNM-M-001` can never be read as PTL `M-001`; the prefix is mandatory on every row and every cross-reference. **Append-only, never renumbered, never reused** — a retired ID is recorded as retired.

⚠ **A third namespace already exists and must not be confused with these.** `coverage-map/metric-coverage.json` uses bare **`PNM-###`** (`PNM-001`…`PNM-167`) for Argus data-dictionary rows. `PNM-012` is an Argus DD id; `PNM-M-012` would be a KB metric row. `CONTRIBUTING.md` will state this distinction explicitly, and `PNM-G-052` records that no mapping between the two exists.

## 2.3 `dashboards.md` → `sources.md` — the shape change, and why

PTL's `dashboards.md` does two jobs: *"where did this number come from?"* and *"has the source moved since we read it?"* Both jobs are needed for PnM. The **artifact type** is not.

PnM has exactly two Metabase cards, and neither is load-bearing: **#30311** is ruled non-authoritative (D6), and **#47576** enters the KB only because the automation's `TPO_TREND_QUERY` *is* that card — it arrives via rung 2, not as a card. PnM's real sources are four named automation queries, two Notion surfaces, a 167-row Argus CSV, a baseline CSV, and a 5-file legacy pipeline. Filing those under a file called `dashboards.md` would make the shelf label a lie.

`sources.md` keeps both jobs and both required columns, and adds a `freshness_check` column naming the *specific* check that applies to that source type (per D-4), since PnM has four different ones.

**Alternative considered and rejected:** keep the name `dashboards.md` with 2 rows and fold everything else into `source_ref` strings. Rejected because it discards the freshness job entirely for 9 of 11 sources — including `PNM_EXPERIENCE`, the one source documented to drift.

**This is the file-list deviation most likely to be wrong. It is Open Question 3.**

## 2.4 PTL files NOT ported — explicit justification

### `query-rules.md` (`Q-###`) — NOT PORTED
PTL's Q-file exists for one reason: an external playbook of **observed production practice** was imported, and it had to be quarantined at tier 5 with a mandatory `collides_with` column so it could be *checked* without being *quoted*.

**PnM's operational practice sits at the TOP of its ladder, not the bottom.** The validated MBR automation is rung 2 and outranks every document. A file whose defining property is "everything in here is tier 5 and may never be read alone" has no PnM referent — building one would either be empty or would misfile PnM's best evidence as its worst.

PnM's genuinely query-shaped rules — prunable-range vs `DATE_TRUNC`, `+330 min` IST, `NULLIF` divide-guard, the `assert_read_only` guard, `crn LIKE '%PNM%'`, the `QUALIFY` dedup — are **read directly out of `sqlgen.py`**, clear the `verified` bar, and belong as ordinary `PNM-T-###` / `PNM-B-###` rows. Filing verified code facts in a tier-5 quarantine file would be a downgrade with no evidentiary basis.

*Reopen if:* an external PnM analyst playbook is ever imported. Then build it, exactly as PTL did.

### `SOP.md` — DEFERRED
SOP §10 prescribes the build order: *"Start with 3 and 4"* — the precedence ladder and the gaps file — and closes *"A KB with ten sourced rows and an honest gaps list beats one with two hundred unsourced ones."* The four loops are largely vertical-agnostic; PnM's material variations (Loop A becomes "a section got reconciled against the automation", and PnM adds a **readiness-promotion loop** PTL has no analogue for) are worth writing **after the KB has been used once**, not guessed at now. Writing a runbook for a workflow nobody has run yet produces fiction.

*Interim:* `CONTEXT.md` and `CONTRIBUTING.md` carry the routing and the law. **Open Question 4 offers the owner an override.**

### `WALKTHROUGH.md` — DEFERRED
PTL's is a 10-minute *why*, written after months of history it can narrate. A PnM equivalent written on day one would be a summary of this spec. Defer until there is a history.

### `coordination/DECISIONS.md`, `coordination/BOARD.md` — NOT CREATED
These live **outside** `kb/` in PTL, and `pnm-selfserve/coordination/` does not exist. Writes are confined to `kb/` plus this spec, so creating them would breach scope. PnM's ladder is written not to depend on them.

### `../DECISION_LOG.md` — NOT CREATED (already exists)
`pnm-selfserve/DECISION_LOG.md` already holds D1–D7 and V1–V3. It is referenced as a sibling exactly as PTL's KB references its own. **Not modified.** The proposed D8–D10 (C13) are *not* written into it — that is the owner's act, not mine.

---

# Part 3 — PnM's precedence ladder, in full

```
1. Owner ruling — DECISION_LOG D1–D7, or an explicit in-session owner ruling      ← strongest
2. The live-validated MBR automation, where a named reconciliation demonstrably happened
   (cited in-repo via its exact mirror, sqlgen.py; the automation itself rides as `local:`)
3. Metabase card SQL, where actually read
4. Data Catalog / INFORMATION_SCHEMA schema metadata
5. metrics_registry.py — behavioural fields (built, readiness, section wiring)
6. iteration-1 metric catalog (the legacy 49-metric pipeline catalogue)
7. iteration-2 ledger · iteration-3 spec (DRAFT) · HANDOFF.md · reference/README.md
   · metrics_registry.py prose fields (definition, aliases)
8. Argus PnM Metrics DD (167 rows) · Notion MoM doc · Notion Demand DB           ← weakest for definitions
```

### Reasoning, rung by rung

**1 — Owner ruling.** *Inverted relative to PTL (divergence D-2).* PnM's load-bearing facts are business-attribution decisions, not computations. D4 — "Nano is labour-only help owned by LA; include it in leads, exclude it from orders and TPO" — cannot be derived from any table; it states which business unit owns a booking. D6 likewise overrides a card by fiat. Where PTL asks *"what does this compute?"*, PnM asks *"whose population is this?"* — and only the owner answers that.

**2 — The validated automation.** SOP §10's named top rung. It clears a **higher** bar than PTL's tier 3: executed against production **and** reconciled field-by-field (V3, exact match, 2026-05). ⚠ Two limits, both stated on every row that leans on it: (a) it is out-of-repo, so it is cited through `sqlgen.py` at a SHA (divergence D-3); (b) V3 covers **one month and 14 of 30 ids**, in 7 comparison rows — outside that slice, "the mirror is exact" is extrapolation (`PNM-G-004`).

**3 — Metabase card SQL.** *Demoted from PTL's rung 1.* Card #30311 is the canonical methodology by `config.py`'s own header and is **ruled non-authoritative** by D6 because it strips Nano from the whole funnel, contradicting D4. A card that lost to a ruling on first contact cannot sit above rulings. Card #47576 is not really at this rung — it *is* the automation's TPO query, entering at rung 2.

**4 — Schema metadata.** *No PTL analogue.* PTL read its schema out of card SQL; PnM's flag resolutions (`hs_tickets` exists and `pnm_application.tickets` does not; the six OTA columns exist nowhere; `fact_pnm_orders` assembles the lifecycle timestamps) all came from Data Catalog `get_column_metadata`. It is authoritative for **existence and type** and silent on **definition**. Placed above the registry because it settles factual disputes that no document can, and below card SQL because it never says what a metric *means*. **It settles factual disputes; it can never settle a definitional fork.**

**5 — Registry behavioural fields.** The registry is *code that runs*: `SECTIONS[…]["built"]` and `["readiness"]` gate `ask.py` at runtime, so they are binding on behaviour in a way no document is.

**6 — iteration-1 catalog.** PTL's rung 4 analogue, but **doubly weakened**: it documents the legacy 5-file pipeline that D3 established could never execute (its columns do not exist on the configured tables) and that D5 replaced. It is a record of *intent*, never of behaviour — and it is unannotated, so it still reads as current (C1–C7).

**7 — Project documents and registry prose.** PTL's rung 5. Three specific weaknesses: `HANDOFF.md` **self-declares stale** in its own header; `iteration-3` is a **DRAFT** and is **untracked** (no SHA); the registry's `definition` strings are *claims about* the SQL, not the SQL, so they are assigned here even though they live in a rung-5 file.

**8 — Argus DD and Notion.** PTL's rung 6 analogue. Authoritative for **which metrics PnM is expected to have** and for **published values** — D6 makes the Notion Demand DB a reconciliation baseline, which is a *value* authority — and never for how a metric is computed.

### Rules that ride with the ladder (all inherited from CONTRIBUTING §6)
- **Tier is a property of the CLAIM, never of the document.** `metrics_registry.py` holds rung-5 and rung-7 claims side by side and is the standing proof.
- **A claim that names no reconciliation surface is rung 7.** Naming one is necessary, not sufficient: if the KB's own reading of that surface contradicts the claim, the reconciliation did not happen.
- **Where a higher rung outranks a KB row, the row's `statement` is CORRECTED**, with the superseded wording preserved verbatim in its `note`. Annotation alone is indistinguishable from no ruling.
- **Tier governs precedence, never confidence.** A rung-1 claim can outrank every row and still be `unverified`.
- **THE ABSOLUTE EXCEPTION (rungs 1 vs 2 only):** where the validated automation's SQL contradicts an owner ruling, **do not resolve it.** Record both sides, set `confidence: unverified`, open a `PNM-G-###` naming the exact action that would settle it.

---

# Part 4 — Seed-row inventory

## 4.1 `source_ref` values, all SHA-verified

Every SHA below was checked byte-identical to the working tree this session.

| Source | `source_ref` form | Max confidence attainable |
|---|---|---|
| `HANDOFF.md`, `DECISION_LOG.md`, `metrics_registry.py`, `sqlgen.py`, `ask.py`, `run_tests.py`, `tests_output/*` | `repo@112c992:<path>#L<n>` | `verified` (code) / `unverified` (docs) |
| `iteration-1-metric-catalog-and-architecture.md` | `repo@a0057ba:<path>#L<n>` | `unverified` |
| `iteration-2-readiness-ledger.md`, `reference/README.md`, `reference/p80_durations_baseline_*.csv` | `repo@c319c05:<path>#L<n>` | `unverified` |
| `selfserve_nlq/README.md` | `repo@582275e:<path>#L<n>` | `unverified` |
| `docs/overview.html` | `repo@5608e74:<path>` | `unverified` |
| Owner rulings | `DECISION_LOG:D1` … `DECISION_LOG:D7`, `DECISION_LOG:V3` | **`verified`** (explicit owner ruling, §4) |
| **`iteration-3-p80-orderedits-spec.md`** | ⚠ **UNTRACKED — no SHA exists.** `local:pnm-selfserve/iteration-3-p80-orderedits-spec.md` | **`unverified` — hard ceiling** |
| **`coverage-map/metric-coverage.json`** | ⚠ **UNTRACKED.** `local:pnm-selfserve/coverage-map/metric-coverage.json` | **`unverified` — hard ceiling** |
| MBR automation | `local:ProdOps/pnm/pnm_mbr_monthly_metrics/queries.py` | **`unverified` — hard ceiling** (D-3) |
| Workspace instructions | `local:ProdOps/CLAUDE.md` | `unverified` |
| Metabase | `metabase:card/30311`, `metabase:card/47576` | `unverified` (not opened this pass) |
| Notion | `notion:3599c6eaaa6d8016b554fc2e8e3bf577` (MoM doc, id carried from iteration-1 §Part 1) | `unverified` |

> ⚠ **Two of PnM's sources are untracked and therefore uncitable at a SHA** — including `iteration-3`, the sole source for D8–D10, and the coverage map, the sole in-repo carrier of the 167-row Argus universe. Their bytes can change with no signal. → `PNM-G-002`.

## 4.2 Expected rows and confidence per file

| File | Rows | `verified` | `unverified` | `assumption` |
|---|---|---|---|---|
| `business.md` | **34** | 9 | 21 | 4 |
| `metrics.md` | **11 blocks** (covering 30 registry ids) + 2 index tables | 8 | 3 | 0 |
| `data-model.md` | **32** | 21 | 9 | 2 |
| `sources.md` | **11** | 2 | 9 | 0 |
| `GAPS.md` | **57** | — *(gap rows carry `status`, not `confidence`)* | — | — |
| **Total addressable rows** | **~145** | **~40 (38%)** | **~42 (40%)** | **~6 (6%)** + 57 gap rows |

**Why the `verified` share is higher than PTL's, and why that is honest.** PTL's business rows are all `unverified` because business context lives in documents. PnM's differ in kind: its four built sections are backed by **`sqlgen.py`, in-repo, at a SHA** — reading it *is* reading the SQL, which is exactly CONTRIBUTING §4's bar. Nine `business.md` rows reach `verified` only because they are **explicit owner rulings** (D1–D7), the third route §4 allows.

Every `verified` row will carry the same standing caveat in `metrics.md`'s header:

> `verified` here attests that **this is what the prototype computes**, read from `sqlgen.py` / `metrics_registry.py` at the cited SHA. V3 showed the prototype equals the owner's automation **exactly — for 2026-05, across 14 of 30 metric ids (7 comparison rows).** Outside that slice the equality is extrapolation (`PNM-G-004`). No row here has been re-validated against the warehouse in this pass; **no query was run.**

### Illustrative rows (exact form proposed)

```
| PNM-B-010 | **Nano = labour-only help (no vehicle or vendor allocated), owned by LA (Labour
  Assist)**, a business group separate from PnM. | `DECISION_LOG:D4` | **verified** | — | Owner
  domain knowledge; derivable from no table. → PNM-B-011, PNM-B-012 |

| PNM-B-011 | **Nano is INCLUDED in leads** — nano demand stays with PnM through the funnel. |
  `DECISION_LOG:D4` | **verified** | — | ⚠ CONTRADICTED for orders by iteration-1 → PNM-G-030 |

| PNM-T-004 | TPO tickets are excluded when `COALESCE(hst.raised_by,'') = 'Detractor'` — exact
  equality, not a pattern match. | `repo@112c992:pnm-selfserve/selfserve_nlq/sqlgen.py` |
  **verified** | ⚠ iteration-1 records the pipeline's filter as `LOWER(raised_by) LIKE
  '%detractor%'`; the two disagree on values like `Detractor-Customer`. → PNM-G-015 |

| PNM-G-045 | **Do owner rulings D8–D10 exist?** | iteration-3 §2 heads them "proposed DECISION_LOG
  entries D8–D10" and each states "Owner-confirmed 2026-07-12" · `DECISION_LOG.md` @ 112c992 stops
  at D7, with no D8/D9/D10 anywhere | Ask the owner: were D8–D10 ruled on 2026-07-12? If yes, they
  are rung 1 and close PNM-G-020/040/041/042/043/046; if no, they are rung 7 and settle nothing.
  **Nothing downstream may be built until this is answered.** | **BLOCKED — owner** |
```

## 4.3 Every gap row, by group

| Group | Range | n | Contents |
|---|---|---|---|
| **A. Provenance & citation integrity** | `PNM-G-001`…`008` | 8 | untracked sources have no SHA (`002`); the top rung is `local:`-capped (`003`); V3's 1-month / 14-of-30 coverage (`004`); the automation is outside version control (`006`); `PNM_EXPERIENCE` schema drift needs a live pre-flight (`007`); card fingerprints unobtainable offline (`008`) |
| **B. Registry/code behaviour with no document behind it** | `PNM-G-011`…`022` | 12 | §1.3 items 1–12 |
| **C. iteration-1 vs owner rulings** | `PNM-G-030`…`037` (+`015`, `019`) | 10 | C1–C7, plus the three further TPO divergences C5b (join key), C5c (vendor prefix match), C5d (attribution mechanism) |
| **D. iteration-3 (DRAFT) vs everything else** | `PNM-G-040`…`047` (+`020`) | 8 | C9–C14, C16, **C13** and **C13b** (`047` — D9 carries no owner stamp yet overrides a committed file) |
| **E. Document-vs-document / document-vs-code** | `PNM-G-050`…`055` (+`022`) | 7 | C8, C17, C19, C20, C21, C22, C24 (`055` — five identical-message commit pairs on divergent branches make message-derived citations ambiguous) |
| **F. Naming & jargon** | `PNM-G-060`…`064` | 5 | **the expansion "Packers & Movers" appears in no PnM or PTL source file** — only in out-of-repo `ProdOps/CLAUDE.md` (`060`); **CRN never expanded** (`061`); **LMS never expanded**, appears only in the untracked coverage map (`062`); OTA/P80/TPO expansions traceable only to the untracked coverage map or to code (`063`); cross-vertical collisions — "allocation", "conversion", "CBDF/CADF/CAC" mean different things in PnM, PTL and HCV (`064`, corroborating PTL's `G-039`) |
| **G. Coverage — not built / not covered** | `PNM-G-070`…`077` | 8 | `ota` BLOCKED, no data source; `p80_durations` and `order_edits` not built; 140 of 167 Argus DD rows untouched; no mapping between the 30 registry ids and the 167 Argus ids; `docs/overview.html`, `ask.py` and `run_tests.py` not mined this pass (§6, OQ5) |
| **Total** | | **~57** | |

---

# Part 5 — What the build would and would not do

**Would:** create exactly the 7 files in §2.1; seed every row from a repo file with a verified `source_ref`; grade confidence per CONTRIBUTING §4; open a `PNM-G-###` for everything unsourceable; state both sides of all 26 conflicts; hold `CONTEXT.md` under 175 lines; read back every `source_ref` to confirm it resolves.

**Would not:** touch anything under `ptl-selfserve/`; touch any existing file under `pnm-selfserve/`; write D8–D10 into `DECISION_LOG.md`; edit `coverage-map/`; run any Metabase, Snowflake or Data Catalog query; resolve any conflict; invent any metric, table, column or formula; commit, push or open a PR.

---

# Part 6 — Open questions for the owner

**OQ1 — Do owner rulings D8 and D10 exist? (BLOCKING for the p80 / order_edits rows.)**
`iteration-3` calls them "proposed DECISION_LOG entries" while stamping D8 and D10 "Owner-confirmed 2026-07-12"; `DECISION_LOG.md` stops at D7. If ruled, they are rung 1 and close five gaps. If proposed, they are rung 7 and close none. *Recommendation: answer before Phase C runs, or accept those rows seeding as `BLOCKED` gaps.*

**OQ1b — And D9 specifically, which claims no confirmation at all?**
A blind check of this spec found that **D9 carries no "Owner-confirmed" stamp** — unlike D8 and D10. Its stated rationale is *"The `_mins` ids were never built, so this is free to supersede"*, which is an authorial argument. Yet **D9 is the only one of the three that overrides a committed, tracked file**: `reference/README.md` @ `c319c05` maps the p80 baseline CSV to the `_mins` ids that D9 discards. So the weakest-evidenced of the three rulings is doing the most damage to existing artifacts. *Answering OQ1 "yes" does not answer this one.*

**OQ2 — Is the rung-1/rung-2 inversion right?** I have placed **owner rulings above the validated automation's SQL**, reversing PTL. My reasoning is D-2 (§1.2): PnM's disputes are attribution, not computation. If you would rather the SQL win, say so — it changes the absolute exception and how C1–C7 are dispositioned.

**OQ3 — `sources.md`, or a thin `dashboards.md`?** §2.3. I recommend `sources.md`; the fallback is a 2-row `dashboards.md` that abandons the freshness job for 9 of 11 sources.

**OQ4 — Port `SOP.md` now, or defer?** I recommend defer, per SOP §10's own "start with 3 and 4". Say the word and it goes in the build.

**OQ5 — May I seed from three in-repo sources not on the brief's read list?** `ask.py` and `run_tests.py` (both `112c992`) hold the trust-footer contract, the MTD-labelling rule, the readiness gate and the `EXPECTED_TABLES` allow-list — all `verified`-grade code facts. `docs/overview.html` (`5608e74`) holds a stale claim worth recording (C21). *Default if you do not answer: they are logged as coverage gaps (`PNM-G-077`) and not mined.*

**OQ6 — Branch.** iteration-3 §12 recommends cutting a fresh branch off the PnM tip `112c992`; this work sits on `claude/ptl-metric-catalog-map`, which carries PTL commits. Separately: PTL's own `kb/CONTEXT.md` asserts PnM material lives only on `claude/pnm-p80-orderedits` @ `851886f` and that "neither branch holds both" — **false on this branch**, which holds both. That is a defect in a PTL file; per the brief I have **not** touched it, and it is not a PnM gap row. Flagging for your call.

## 7.1 One pre-existing condition you should know about

`git status` shows **`M pnm-selfserve/selfserve_nlq/tests_output/dry_run_report.md`** — modified **before this session began**. The diff is a 2026-08-14 re-run of `run_tests.py` that dropped the `[MTD-labeled]` markers the committed 2026-07-08 version carries (July 2026 is no longer in progress). It is benign, it is not mine, and the brief forbids me from touching any existing PnM file — so I have left it exactly as found and recorded the underlying reproducibility issue as `PNM-G-054`.

**Consequence for the done-condition** *"git status shows ZERO modified files"*: after Phase C, `git status` will show this one pre-existing modification plus only untracked new files under `pnm-selfserve/kb/` and this spec. Clearing it requires either a `git checkout` of that file or committing it — **both are your call, not mine.**

---

## Approval

Phase C will not start until you approve. Please answer **OQ1 and OQ1b** at minimum; OQ2–OQ6 have stated defaults I will follow if you say only *"approved, defaults"*.

---

## Revision note — 2026-08-25, post blind gate

This spec was checked by a blind subagent given the sources and the bare claims, never the reasoning (global CLAUDE.md §7). It refuted three of twenty-five claims; all three are corrected above:

1. **D9 carries no owner confirmation** — the spec had asserted all three of D8/D9/D10 did. This is not a wording fix: it splits OQ1 and makes D9 the weakest-evidenced ruling doing the most damage (C13b, `PNM-G-047`).
2. **V3's coverage was overstated as "~13 of 30"** — it is 14 of 30 ids across 7 comparison rows.
3. **A self-falsifying sentence** — "'Packers & Movers' appears nowhere in this repo" was false the moment this spec was written into the repo. Reworded to name PnM and PTL *source files*.

It also surfaced four things the spec had missed, now folded in: three further TPO divergences (C5b/C5c/C5d), that "25 metrics" contradicts iteration-1's own headings as well as the code (C8), and five identical-message commit pairs on divergent branches that make message-derived citations ambiguous (C24).
