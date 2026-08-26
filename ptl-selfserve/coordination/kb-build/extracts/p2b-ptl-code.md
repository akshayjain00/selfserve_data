# P2b — PTL self-serve prototype: metric registry & SQL, as implemented in code

Source clone: `/Users/akshay.jain/Desktop/AI_V2/ProdOps/selfserve/pnm/selfserve_data`
Branch `claude/ptl-metric-catalog-map` · commit `7a43470` (verified via `git rev-parse HEAD` = `7a4347036f3fca1d87f24ac482c418a14592ad28`)
Citation format: `repo@7a43470:ptl-selfserve/selfserve_nlq/<file>#L<n>`

No credentials, tokens, or connection strings were found in any of the read files.

---

## Metric registry — one section per metric

All 11 metrics live in `METRICS = {m.id: m for m in [...]}` in metrics_registry.py, built from the shared `core.Metric` dataclass (repo@7a43470:ptl-selfserve/selfserve_nlq/core.py#L34-L58). Two cross-cutting assumptions apply to every metric (stated verbatim in the module docstring, repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L15-16):
- "orders.state enum 3=completed / 4=cancelled is ASSUMED (pre-work P1, unconfirmed)."
- "internal/test mobiles are excluded via partload_analytics.ptl_internal_users."

All sections (`demand`, `fulfilment`, `cancellations`, `marketplace`, `retention`) carry `readiness: "prototype_only"` (repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L32-38). Nothing is `stakeholder_ready`.

Config-wide flags carried on every answer (repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L23-29), quoted verbatim:
- "orders.state enum (3=completed, 4=cancelled) assumed, not confirmed (P1)"
- "offline gsheet status_code -> enum is UNMAPPED (unrecognised -> NULL, not counted); incl_offline completed/cbdf/cadf unreliable until OFFLINE_STATUS_CONFIRMED"
- "business-user filter (customers.frequency IN (1,2,3,4)) source+key unconfirmed: oms_public.customers vs prod_eldoria.core.dim_customers (§3.5)"
- "internal-user exclusion applied inconsistently across source cards (catalog §3)"
- "Metabase db108 vs db73 not yet confirmed to be the same Snowflake account (P2)"

Two module-level confirmation gates (both `False` in code): `STATE_ENUM_CONFIRMED = False` and `OFFLINE_STATUS_CONFIRMED = False` (repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L20-21). `ask.py` refuses `--execute` while these are unset (repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L74-80).

### 1. `nsm_txn_business_customers`
- Display: North Star Metric — "Distinct business customers with >=1 completed PTL order in the month (North Star, D4)." — repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L46-48
- Type: `simple` (registry) but downgraded to `"authored"` kind in the SQL plan — no column is actually emitted; see Contradictions.
- Section/level/unit: demand / NSM / customers
- Source card: `None` (no source card at all) — repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L48
- Tables (registry-declared): `prod_curated.partload_application.orders` + "customer classification (dim_customers OR oms_public.customers)" [vague/uncertain — the registry itself gives two alternatives] — repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L49
- both_bases: True
- Verify flags (verbatim): "AUTHORED — no source card; definition written from D4, must be owner-confirmed"; "customer Business/Personal source+key drift (catalog §3.5): dim_customers.customer_uuid vs oms_public.customers on customer_mobile" — repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L51-53
- SQL plan: `("orders", "authored", "distinct_business_customers")` with inline comment "# deferred: column not emitted; NSM authored, no card" — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L170
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L45-55

### 2. `completed_orders_business`
- Display: "Count of completed PTL orders by business users in the month." — L58
- Type: simple, L0, orders. Card: `33462`.
- Tables: `orders`, `order_vehicles`, `prod_curated.gsheet_sync.ptl_offline_orders`, `prod_eldoria.core.dim_customers` — repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L60
- both_bases: True
- Verify flag (verbatim): "card 33462 UNIONs offline orders; base differs from cards that exclude them (§3.3)" — L61
- SQL plan: `("orders", "simple", "completed")` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L161. Actual value = `COUNT(DISTINCT CASE WHEN state = 3 THEN okey END)` in orders_sql — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L79.
- Note: registry lists `order_vehicles` and `dim_customers` as source tables, but the actual `orders_sql`/`_online_base` builder never selects from `dim_customers` (only touches `orders`, `order_vehicles` via EXISTS, `ptl_internal_users`, `oms_public.customers`, and offline). `order_vehicles` is used only to derive `vehicle_assigned` (cbdf/cadf), not for the completed-orders count itself.
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L56-63

### 3. `new_business_users`
- Display: "Count of new business users (first completed PTL order) in the month." — L66
- Type: simple (registry), L1, users. Card: `48921`.
- Tables: `orders`, `prod_curated.oms_public.customers` — L68
- both_bases: True
- Verify flag (verbatim): "card 48921 counts ONLINE only; classification from oms_public.customers (frequency IN (1,2,3,4))" — L69
- SQL plan: `("orders", "authored", "new_business_users")` with inline comment "# deferred: needs first-order-ever logic" — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L171. **No "first order ever" logic exists anywhere in sqlgen.py** — no column is emitted for this at all; per `ask.py` this metric prints a "no number computed" note (repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L66-68).
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L64-71

### 4. `business_session_conversion`
- Display: "Share of PTL business-user sessions that result in a placed order." — L74
- Type: ratio, numerator="orders", denominator="sessions", scale=100.0. Card: `48491`.
- **both_bases: False** — explicit inline comment "D6 note: offline orders have no session -> not applicable" — L76
- Tables (registry-declared): `partload_analytics.ptl_fe_events`, `orders`, `prod_eldoria.core.dim_customers` — L77
- Verify flag (verbatim): "session funnel — offline base does NOT apply (no session for offline orders)" — L78
- SQL plan: `("session", "ratio", ("orders","sessions",100.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L168
- Grain/time basis: `e.event_ts`, IST month window via `DATEADD('minute', -330, ...)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L121-122
- Actual implementation (`session_sql`) touches **only** `ptl_fe_events` and `ptl_internal_users` — never `orders` or `dim_customers` as the registry's tables list claims. Business classification is done via `e.user_type = 'Business'` (marked `/*⚠VERIFY business classification*/`), not via the `customers.frequency` filter used elsewhere.
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L72-80; SQL repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L114-130

### 5. `total_fulfilment_pct`
- Display: "Completed / placed PTL orders (also tracked excluding <60s cancellations)." — L84
- Type: ratio, numerator="completed", denominator="placed", scale=100.0. Card: `4198`. both_bases: True.
- Tables: `orders`, `order_cancellation_reasons`, offline gsheet — L87
- Verify flag (verbatim): "dashboard 4198 has a separate '<60s excluded' variant (43238) — report both" — L88
- SQL plan: `("orders","ratio",("completed","placed",100.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L162
- Formula as executed: `COUNT(DISTINCT CASE WHEN state=3 THEN okey END) / COUNT(DISTINCT okey)` × 100, aggregated first (ratio computed in `ask.py::compute`, repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L38-49), never per-day-averaged.
- No `<60s` exclusion logic exists anywhere in sqlgen.py — the "also tracked" variant named in the definition is not implemented; only 4198's un-excluded version is built. See Contradictions.
- `order_cancellation_reasons` is listed as a source table but is **never referenced** by any builder function (see Tables section). See Contradictions.
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L82-90

### 6. `effective_fulfilment_pct`
- Display: "Completed / (placed - customer-attributed cancellations)." — L93
- Type: ratio, numerator="completed", denominator="placed_less_cx_cancels", scale=100.0. Card: `48581`. both_bases: True.
- Tables: `orders`, `order_cancellation_reasons`, `ptl_internal_users` — L96
- Verify flags (verbatim): "card 48581 EXCLUDES offline — base differs from total_fulfilment_pct's 4198 (§3.3)"; "prototype denominator = placed − cbdf_cancels (APPROXIMATION); card 48581's exact 'customer-attributed cancellations' needs confirming" — L98-100
- SQL plan: `("orders","ratio",("completed","placed_less_cbdf",100.0))` with inline `# ⚠VERIFY vs card 48581 'customer-attributed' denom (cbdf ≈ approximation)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L163
- Denominator as executed: `placed_less_cbdf = COUNT(DISTINCT okey) - COUNT(DISTINCT CASE WHEN state=4 AND vehicle_assigned=0 THEN okey END)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L82-83. This matches the registry's own flagged approximation (no contradiction here — self-declared).
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L91-102

### 7. `cbdf_pct`
- Display: "Cancellations BEFORE a driver/vehicle is found / placed orders (D5: dashboard 4793 logic)." — L106
- Type: ratio, numerator="cbdf_cancels", denominator="placed", scale=100.0. Card: `4793`. both_bases: True.
- Tables: `orders`, `order_cancellation_reasons`, `order_vehicles` — L109
- Verify flags (verbatim): "TWO parallel defs (§3.4): dashboard 4793 (canonical, D5) vs card 49366 (vehicle_name IS NULL). Confirm reconcile."; "prototype uses 49366-style vehicle-assigned signal and does NOT yet apply 4793's <60s exclusion → cancel counts over-stated until reconciled" — L110-112
- SQL plan: `("orders","ratio",("cbdf_cancels","placed",100.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L164
- Formula as executed: `cbdf_cancels = COUNT(DISTINCT CASE WHEN state=4 AND vehicle_assigned=0 THEN okey END)`; `vehicle_assigned` = `EXISTS (SELECT 1 FROM order_vehicles ov WHERE ov.order_external_id = o.external_id)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L48-50, L80
- `order_cancellation_reasons` never actually queried (see Tables/Contradictions).
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L104-115

### 8. `cadf_pct`
- Display: "Cancellations AFTER a driver/vehicle is found / placed orders (D5: dashboard 4793 logic)." — L118
- Type: ratio, numerator="cadf_cancels", denominator="placed", scale=100.0. Card: `4793`. both_bases: True.
- Tables: `orders`, `order_cancellation_reasons`, `order_vehicles` — L121
- Verify flag (verbatim): "TWO parallel defs (§3.4): 4793 canonical vs 49366. Confirm reconcile." — L122
- SQL plan: `("orders","ratio",("cadf_cancels","placed",100.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L165
- Formula as executed: `cadf_cancels = COUNT(DISTINCT CASE WHEN state=4 AND vehicle_assigned=1 THEN okey END)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L81
- Note: unlike its sibling `cbdf_pct`, this metric's verify_flags do **not** repeat the "<60s exclusion not applied" caveat, even though `cadf_cancels` is derived from the exact same un-excluded `state=4` signal — see Contradictions (minor).
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L116-124

### 9. `avg_orders_per_trip`
- Display: "Fulfilled orders / trips where >=2 orders shared a route+date (clubbing)." — L128
- Type: ratio, numerator="clubbed_orders", denominator="clubbing_trips", scale=1.0. Card: `33461`. **both_bases: True** (registry).
- Tables: `batched_orders_v1`, `order_vehicles`, `orders`, offline gsheet — L131
- Verify flag (verbatim): "card 33461 UNIONs offline orders (§3.3)" — L132
- SQL plan: `("trips","ratio",("clubbed_orders","clubbing_trips",1.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L167
- Formula as executed (`trips_sql`): trips CTE joins `batched_orders_v1` to `orders` (plain `JOIN`, not EXISTS) on `order_external_id = external_id`, filtered to the IST month window and `state = 3`, grouped by `batch_id`; `clubbed_orders = SUM(orders_on_trip WHERE orders_on_trip>=2)`, `clubbing_trips = COUNT(trips WHERE orders_on_trip>=2)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L96-109
- **Only ONE row (`basis='excl_offline'`) is ever emitted** despite `both_bases=True` and offline/`order_vehicles` being listed as source tables — neither is referenced in `trips_sql`. Also no internal-user or business-user filter is applied in this builder at all. See Contradictions.
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L126-134

### 10. `aov`
- Display: "Total revenue from completed orders / count of completed orders." — L137
- Type: ratio, numerator="revenue", denominator="completed", scale=1.0. Card: `33706`. both_bases: True.
- Tables: `orders`, `partload_analytics.ptl_routes` — L140
- Verify flags (verbatim): "card 33706 buckets by updated_at, not created_at like the funnel (§3.6) — pick one date basis"; "card 33706 EXCLUDES offline (§3.3)" — L142-143
- SQL plan: `("orders","ratio",("revenue_completed","completed",1.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L166
- Formula as executed: `revenue_completed = SUM(CASE WHEN state=3 THEN revenue ELSE 0 END)` where `revenue = o.estimated_fare` (online) or `so.fare` (offline) — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L45, L66, L84
- Grain: shares the `orders_sql` builder, so date basis is `o.created_at` (not `updated_at` as the source card 33706 allegedly uses) — the registry's own flag names this unreconciled discrepancy. `ptl_routes` is listed as a source table but never referenced in sqlgen.py.
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L135-146

### 11. `m1_business_retention_pct`
- Display: "Share of month-0 business users who place >=1 PTL order in month+1." — L150
- Type: ratio, numerator="m0_retained", denominator="m0_business_users", scale=100.0. Card: `4569`. **both_bases: True** (registry).
- Tables: `orders`, `prod_curated.oms_public.customers` — L153 (no offline table listed here, despite both_bases=True)
- Verify flag (verbatim): "cohort/retention — confirm month-0 base and completed-vs-placed basis on dashboard 4569" — L154
- SQL plan: `("retention","ratio",("m0_retained","m0_business_users",100.0))` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L169
- Formula as executed (`retention_sql`): `m0` = distinct `customer_mobile` from `orders` in month `[ms,me)`, `state=3`, NOT internal user, EXISTS business-user (frequency IN (1,2,3,4)); `m1` = distinct `customer_mobile` from `orders` in month `[me,me2)`, `state=3` **only** (no internal-user or business-user re-filter applied to m1); `m0_retained = COUNT(m0 rows whose mobile IN m1)` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L136-152
- Only ONE row (`basis='excl_offline'`) is emitted despite `both_bases=True`. See Contradictions.
- Citation: repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L148-156

### Deferred (not part of the 11)
- `time_to_allocate_p50`: "manual sheet source, no verified card — iteration 2.5 (D6)" — repo@7a43470:ptl-selfserve/selfserve_nlq/metrics_registry.py#L160-162

---

## Tables & columns touched

| Table (schema.table) | Columns referenced in actual SQL | What the code says it represents | Citation |
|---|---|---|---|
| `prod_curated.partload_application.orders` | `external_id`, `state`, `estimated_fare`, `created_at`, `customer_mobile` | Online PTL orders; base for demand/fulfilment/cancellations/AOV/retention/trips | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L24, L43-57, L100-104, L136-149 |
| `prod_curated.partload_application.order_vehicles` | `order_external_id` (existence check only) | Vehicle-assignment signal used to split cancellations into cbdf/cadf ("49366-style", explicitly un-reconciled vs dashboard 4793) | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L25, L48-50 |
| `prod_curated.partload_application.order_cancellation_reasons` | *(none — declared but unused)* | Declared as `_CR` constant; listed in the registry as a source table for `total_fulfilment_pct`, `effective_fulfilment_pct`, `cbdf_pct`, `cadf_pct` | Declared: repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L26. **Never referenced in any builder function or any rendered SQL file.** [inferred: dead/unused constant] |
| `prod_curated.partload_analytics.ptl_internal_users` | `mobile` | Internal/test-user exclusion list, applied via `NOT EXISTS` anti-join | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L27, L54, L124, L141 |
| `prod_curated.gsheet_sync.ptl_offline_orders` | `order_crn`, `status_code`, `fare`, `month_start` | Offline (gsheet-synced) orders unioned into the `incl_offline` basis; `status_code`→enum mapping is UNMAPPED (unrecognised → NULL, not counted) | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L28, L60-70 |
| `prod_curated.partload_application.batched_orders_v1` | `batch_id`, `order_external_id` | Clubbing/trip batches for `avg_orders_per_trip` | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L29, L96-104 |
| `prod_curated.partload_analytics.ptl_fe_events` | `session_id`, `event`, `event_ts`, `user_type`, `mobile` | Frontend session events; `user_type='Business'` is the business classifier for the session funnel (different mechanism from `customers.frequency`) | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L30, L117-125 |
| `prod_curated.oms_public.customers` | `mobile`, `frequency` | Business-user classification via `frequency IN (1,2,3,4)`, applied to `orders`-based CTEs (online base, retention m0) | repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L31, L55-56, L142 |
| `prod_eldoria.core.dim_customers` | *(none in code — registry-only)* | Listed in registry as a source table for `completed_orders_business`, `business_session_conversion`, `m1_business_retention_pct`'s NSM sibling alternative | metrics_registry.py#L49, L60, L77. **Never appears in sqlgen.py or any rendered SQL.** [inferred: registry-declared, code-absent] |
| `prod_curated.partload_analytics.ptl_routes` | *(none in code — registry-only)* | Listed as a source table for `aov` | metrics_registry.py#L140. **Never referenced in sqlgen.py.** [inferred: registry-declared, code-absent] |

---

## SQL patterns observed (from the 4 rendered .sql files)

**Join structure**
- `rendered_orders_2026-04.sql`: no `JOIN` at all — vehicle-assignment and both anti-fraud/business filters use `EXISTS`/`NOT EXISTS` subqueries against `order_vehicles` (L6-7), `ptl_internal_users` (L12), `oms_public.customers` (L13-14). Two CTEs (`online`, `offline`) are combined via plain `UNION ALL` inside a subquery (L35) for the `incl_offline` aggregate; the `excl_offline` aggregate reads `online` directly (L46).
- `rendered_trips_2026-04.sql`: uses a plain `INNER JOIN` between `batched_orders_v1` and `orders` (L5) — this is the one builder that departs from the "EXISTS not JOIN" pattern (see Contradictions). No internal-user or business-user filter is applied anywhere in this file.
- `rendered_session_2026-04.sql`: single-table aggregation from `ptl_fe_events` with one `NOT EXISTS` anti-join (L8) for internal-user exclusion; no join to `orders`/`customers`/`dim_customers`.
- `rendered_retention_2026-04.sql`: two independent CTEs (`m0`, `m1`) each scanning `orders` directly (no joins); retained-count uses a positive `IN` membership subquery (L17: `mobile IN (SELECT mobile FROM m1)`), not an anti-join — this is a plain membership test, unrelated to the NOT-IN/NOT-EXISTS avoidance rule since it's checking presence, not absence.

**Date / timezone handling**
- All four files uniformly convert IST month boundaries via `DATEADD('minute', -330, DATE 'YYYY-MM-DD')` applied to a **bare** timestamp column (`created_at` / `event_ts`), never wrapping the column itself in an expression — e.g. `rendered_orders_2026-04.sql#L10-11`, `rendered_trips_2026-04.sql#L6-7`, `rendered_session_2026-04.sql#L5-6`, `rendered_retention_2026-04.sql#L4-5, L12-13`. Inline comment: "IST month start (data is UTC; CLAUDE.md rule; bare column preserves pruning)" — `rendered_orders_2026-04.sql#L10`.
- `rendered_retention_2026-04.sql` computes month+1 bounds by re-deriving `month_bounds()` on the prior month's end (`me[:7]`) — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L135.

**Dedup / anti-join patterns**
- `COUNT(DISTINCT okey)` used throughout `rendered_orders_2026-04.sql` (L28-34, L39-45) to dedupe on a namespaced key (`'ON:' || external_id` / `'OFF:' || order_crn`), preventing double-count across the online/offline union.
- `NOT EXISTS` anti-join for internal/test-user exclusion appears in `rendered_orders_2026-04.sql#L12`, `rendered_session_2026-04.sql#L8`, `rendered_retention_2026-04.sql#L6` — absent from `rendered_trips_2026-04.sql`.
- `EXISTS` (not `IN`) for the business-user filter: `rendered_orders_2026-04.sql#L13-14`, `rendered_retention_2026-04.sql#L7` (m0 only, not m1).

**Guard / safety logic**
- Every builder result passes through `assert_read_only()` before being returned (repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L90, L110, L129, L153), which (repo@7a43470:ptl-selfserve/selfserve_nlq/core.py#L65-83): rejects anything not starting with `WITH`/`SELECT`, strips string literals and comments before checking for a stray `;` (multi-statement guard), regexes for write/DDL keywords, blocks `SYSTEM$`/`EXECUTE`, blocks unsubstituted `{{param}}`/`<param>` template leftovers, and optionally re-parses with `sqlglot` (if installed) to confirm the AST root is a `SELECT`/`WITH`/`Union`/`Subquery`.
- `ask.py::_execute` sets `ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 120` before running (repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L98) and connects with a role read from `SF_ROLE` env var with an inline comment flagging it must be a read-only role (repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L94).
- `--execute` is blocked while `STATE_ENUM_CONFIRMED=False`, and additionally blocked for any `both_bases` metric while `OFFLINE_STATUS_CONFIRMED=False` (repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L74-80).
- Ratios are computed only in `ask.py::compute` after rows are fetched — aggregate-then-ratio, divide-by-zero → `None` (`out[basis] = None if not den else round(...)`, repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L44-46) — SQL itself only returns raw counts.

---

## Contradictions

**CONFLICT: sqlgen.py's own "hardened" claim ("no fan-out (EXISTS not JOIN)") is violated by `trips_sql`.**
- Side A (comment): "Hardened after the 2026-07-23 blind-checker review ... no fan-out (EXISTS not JOIN)" — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L18-19
- Side B (code): `trips_sql` uses a plain `JOIN prod_curated.partload_application.orders o ON o.external_id = b.order_external_id` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L100, confirmed in repo@7a43470:ptl-selfserve/selfserve_nlq/tests_output/rendered_trips_2026-04.sql#L5
UNRESOLVED

**CONFLICT: sqlgen.py's own claim ("both_bases metrics (D3) emit TWO rows") is violated for `avg_orders_per_trip` and `m1_business_retention_pct`.**
- Side A (comment + registry): "both_bases metrics (D3) emit TWO rows — basis='incl_offline' / 'excl_offline'" — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L13; registry marks `avg_orders_per_trip.both_bases=True` (metrics_registry.py#L130) and `m1_business_retention_pct.both_bases=True` (metrics_registry.py#L152)
- Side B (code): `trips_sql` emits a single `SELECT 'excl_offline' AS basis, ...` (repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L106, rendered_trips_2026-04.sql#L11); `retention_sql` likewise emits only `SELECT 'excl_offline' AS basis, ...` (repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L150, rendered_retention_2026-04.sql#L15). Neither builder references the offline table at all.
UNRESOLVED

**CONFLICT: `order_cancellation_reasons` is registry-declared as a source table for 4 metrics but never queried.**
- Side A (registry): listed in `tables` for `total_fulfilment_pct` (L87), `effective_fulfilment_pct` (L96), `cbdf_pct` (L109), `cadf_pct` (L121)
- Side B (code): the `_CR` constant is defined once (repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L26) and never used in any builder function or rendered SQL file. Cancellation logic is derived entirely from `orders.state=4` plus the `order_vehicles` EXISTS check.
UNRESOLVED

**CONFLICT: `new_business_users` is registered as a `simple` metric with card `48921`, but the SQL plan silently downgrades it to `"authored"` with no computed column.**
- Side A (registry): `metric_type` defaults to `"simple"`, `card_id="48921"`, verify_flags only mention "counts ONLINE only" — no mention that the metric is unimplemented (metrics_registry.py#L64-70)
- Side B (code): `sqlgen.METRIC_PLAN["new_business_users"] = ("orders","authored","new_business_users")  # deferred: needs first-order-ever logic` — repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L171. No first-order logic exists in `orders_sql`; `ask.py` prints "[NOTE] AUTHORED metric ... No number computed." for this id (repo@7a43470:ptl-selfserve/selfserve_nlq/ask.py#L66-68).
UNRESOLVED

**CONFLICT (minor): `total_fulfilment_pct`'s definition names a "<60s cancellations excluded" tracked variant that does not exist in code.**
- Side A (registry definition): "Completed / placed PTL orders (also tracked excluding <60s cancellations)." — metrics_registry.py#L84
- Side B (code): no `<60s` / duration-based filter exists anywhere in `sqlgen.py`; only the un-excluded 4198-style ratio is built. The verify_flag itself only says "report both" (L88), it does not claim the second variant is implemented.
UNRESOLVED

**CONFLICT (minor): `cadf_pct`'s verify_flags omit the "<60s exclusion not applied" caveat that its sibling `cbdf_pct` carries, despite sharing the identical un-excluded `vehicle_assigned` signal.**
- Side A: `cbdf_pct` verify_flags state "does NOT yet apply 4793's <60s exclusion → cancel counts over-stated until reconciled" (metrics_registry.py#L112)
- Side B: `cadf_pct` verify_flags (metrics_registry.py#L122) carry only the "TWO parallel defs" flag, not the <60s caveat, even though `cadf_cancels` is computed from the same `state=4`/`vehicle_assigned` signal (repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L81) with no duration filter applied.
UNRESOLVED

**CONFLICT (minor): `avg_orders_per_trip` and `trips_sql` apply neither the internal-user exclusion nor the business-user filter, unlike every other metric's builder.**
- Side A (module docstring/config flags): "internal/test mobiles are excluded via partload_analytics.ptl_internal_users" is framed as a cross-cutting assumption applying "to every metric below" (metrics_registry.py#L13-16); sqlgen.py's hardening note claims "business-user filter applied" as a global fix (sqlgen.py#L20)
- Side B (code): `trips_sql` (repo@7a43470:ptl-selfserve/selfserve_nlq/sqlgen.py#L96-109, rendered_trips_2026-04.sql) has no `NOT EXISTS ptl_internal_users` clause and no `EXISTS oms_public.customers ... frequency IN (1,2,3,4)` clause — it filters only on date range and `state=3`.
- Note: CONFIG_WIDE_FLAGS already partially pre-acknowledges this class of issue generally ("internal-user exclusion applied inconsistently across source cards"), but that flag is about *source Metabase cards*, not about this prototype's own generated SQL.
UNRESOLVED

---
