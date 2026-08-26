# P2a — PTL Core Extract (inventory only, no adjudication)

Sources (pinned): `repo@7a43470` on branch `claude/ptl-metric-catalog-map`, all under `ptl-selfserve/`:
1. `DECISION_LOG.md` (~95 lines) — domain authority, owner rulings D1–D7.
2. `iteration-1-ptl-metric-catalog.md` (~396 lines) — metric catalog.
3. `iteration-1-ptl-journey-proposal.md` (~254 lines) — journey + ranked open questions.

Citation format used throughout: `repo@7a43470:ptl-selfserve/<file>#L<n>`.

---

## D-rulings (verbatim)

### D1 — Consumption model: generate the monthly review doc FIRST (was Q0)
- **Status:** ACTIVE · **Confidence:** 70%
- "Product output #1 is an **auto-generated monthly PTL review** from the registry — removes the manual monthly rewrite (the real pain) and is the strongest leadership demo. Ad-hoc NL Q&A comes later on the same engine."
- **Consequence:** "the deterministic engine is the substrate; the first thing built on top is a doc/trend generator, not a query CLI."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L15-18`

### D2 — Source path: raw `partload_application` now, governed later (was Q1)
- **Status:** ACTIVE · **Confidence:** 75%
- "Build on raw `PROD_CURATED.partload_application` where the numbers actually live; use governed `PROD_ELDORIA.core.fact_ptl_orders` for orders where it already suffices; migrate fully when CATEGORY_ANALYTICS adds measures + cancellation/allocation models."
- **Evidence:** "governed fact exists but has 0 measures and is bypassed by 13/14 cards (catalog §2–3)."
- **Consequence:** "prototype is bug-for-bug with the chosen dashboards on raw tables; quirks disclosed in the answer footer. Do **not** block delivery on another team's roadmap."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L20-24`

### D3 — Offline-order base: NOT locked yet — prototype must SHOW BOTH (was Q2)
- **Status:** OPEN BY DESIGN (conflict-exposure) · owner rules after seeing the gap
- "Every ratio (FF, effective FF, AOV, conversion, avg-orders/trip) must be emitted **with AND without** `prod_curated.gsheet_sync.ptl_offline_orders`, side-by-side, until the owner picks the canonical base."
- **Why:** "cards disagree today (catalog §3.3); the offline gap size should inform the ruling, not a guess."
- **Consequence:** "this is the Track-B 'expose, don't silently pick' requirement made concrete."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L26-30`

### D4 — North Star = "Monthly Transacting Business Customers on PTL" (was Q3)
- **Status:** ACTIVE · **Confidence:** 80%
- "Matches the live May'26 review + the sheet (Apr-26 = 2247). Supersedes the older Project-Argus '30-day repeat rate' framing (treated as stale)."
- **Consequence:** "NSM anchors the registry top and the generated review. Repeat-rate / retention metrics remain as supporting L1s."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L32-35`

### D5 — Canonical cancellation definition = Dashboard 4793 (was Q4)
- **Status:** ACTIVE (pending reconciliation check) · **Confidence:** 65%
- "CBDF/CADF follow the 'PTL Cancellations' dashboard 4793 (carries the <60s-cancellation exclusion the review reports)."
- **Gate:** "before CBDF/CADF ship, confirm standalone card 49366's simpler logic (`order_vehicles.vehicle_name IS NULL/NOT NULL`) **reconciles** to 4793 (owner-run). If it diverges materially, revisit."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L37-40`

### D6 — v1 bundle = 11 Snowflake metrics (8 lineage-traced + 3 to firm up) (was Q5)
- **Status:** ACTIVE · **Confidence:** 70%
- "In v1: **NSM (Monthly Transacting Business Customers), Completed Orders (business), Total Fulfilment %, Effective Fulfilment %, CBDF %, CADF %, Avg Orders per Trip (clubbing), AOV, Business Session Conversion, New Business Users, M1 Business Retention.**"
- **Deferred:** "Time-to-Allocate P50 → iteration 2.5 (source is a manual sheet, no verified card — would drag v1 trust down)."
- **CORRECTION (verification pass 2026-07-23):** "the earlier wording '11 card-verified' drifted from the catalog evidence. Accurate status of the 11:
  - **8 confirmed-via-metadata** (card exists + tables traced): Completed Orders #19, Total FF #26, Effective FF #38, Avg Orders/Trip #46, AOV #55, Session Conversion #14, New Business Users #12, M1 Retention #39.
  - **NSM #2 has NO card** (source = 'Raw Data/production'). Its definition must be **authored** (distinct business customers with ≥1 completed order/month), not mirrored — and it inherits the customer-classification drift (§3.5). It is the metric D4 anchors on, so it must be right.
  - **CBDF #28 / CADF #30 are the conflicted pair** (catalog ⚠️). D5 makes dashboard 4793 canonical; they promote **only after** the 4793↔49366 reconciliation gate."
- **v1 build note:** "the D3 'both-bases' rule applies to order-count ratios (FF, Eff FF, AOV, Avg Orders/Trip, Completed Orders). It does **not** apply to **Business Session Conversion #14** — offline orders have no session, so they are naturally outside the funnel denominator; do not add an offline variant there."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L42-50`

### D7 — Architecture: shared CORE ENGINE only; per-vertical registries; forward-migrate (shared-engine question)
- **Status:** ACTIVE · **Confidence:** 75%
- "Extract the mechanical/safety layer into a shared `core/` both verticals import: read-only SQL guard (regex + sqlglot AST), dry-run CLI scaffolding, answer/trust footer, resolver + refusal mechanics, test-harness utilities, and the registry **schema**. **Metric catalogs stay per-vertical** (separate namespaces)."
- **Forward-migration:** "PTL builds on the freshly-extracted core; PnM migrates later when convenient — **no big-bang refactor of validated PnM work now**."
- **Not now:** "a shared cross-vertical metric namespace — it hits the unsolved B-002 name-collision (PnM/HCV/PTL all have 'allocation'/'fulfilment'/'CBDF') and needs a domain-disambiguation layer first."
- Citation: `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L52-56`

### Also authoritative but not a lettered D-ruling — Pre-work gates (§2)
- **P1** — "Confirm the `orders.state` enum (assumed 3 = completed, 4 = cancelled). Cheapest, highest-leverage check: if wrong, every fulfilment & cancellation number is wrong. Confirm via data dictionary / catalog metadata or owner knowledge — **not** a production query. (catalog flag F17)" — `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L62`
- **P2** — "Confirm Metabase db108 vs db73 resolve to the same Snowflake account/role before treating the one governed-layer card (36421) as comparable to the rest (catalog §3.2)." — `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L63`

### Constraints reaffirmed (§4, carried forward — verbatim)
"Dry-run default; **no production query without showing exact SQL + explicit owner go-ahead**; ratios computed from raw counts (never averaged); MTD-vs-locked-month labeled; section readiness owner-promoted only; nothing opened to stakeholders; AI never authors SQL." — `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L77`

### Status note — Track B (§5)
"Per D1/D2/D6: a dry-run engine over the 11-metric v1 bundle on raw `partload_application`, emitting the offline/online both-bases view (D3), on the shared core (D7). No production data touched without a go-ahead. **Owner said GO 2026-07-23 — build in progress** (`selfserve_nlq/`)." — `repo@7a43470:ptl-selfserve/DECISION_LOG.md#L83`

---

## Metric catalog inventory

Verification-status legend as stated in the doc (`repo@7a43470:ptl-selfserve/iteration-1-ptl-metric-catalog.md#L152-159`):
- **✅ confirmed-via-metadata** — "the stated source card/dashboard exists and its underlying tables were traced via Metabase/Data Catalog metadata. This is existence + lineage, NOT numeric validation (no query was run)."
- **◻️ unverified** — "not checked this iteration: no card opened, or source is Amplitude / Freshdesk / Survey / Manual / DataDog / Sheets / Finance / raw-with-no-card. Default per lesson 4."
- **⚠️ contradicted—conflict** — "a source-of-truth disagreement or latent break was found; described inline and in §3."

All rows below carry the doc's own wording verbatim in the status/flags column — none upgraded or normalized. Row numbers (#) are the sheet's own row numbers (#1 is a header row, excluded; #2–#86, 85 rows total; numbering is non-sequential across some section boundaries in the source — carried as-is).

| # | catalog_name | one-line definition (as stated) | source dashboard/card ref | underlying tables named | verification status + uncertainty flags (verbatim) | citation |
|---|---|---|---|---|---|---|
| 2 | Monthly Transacting Business Customers on PTL (NSM) | Unique business users completing ≥1 PTL order/month | Snowflake → "Raw Data/production" (no card) | — | ◻️ unverified · ⚠️ NSM naming conflict (§1.2) | `...#L168` |
| 3 | PTL Awareness Rate amongst Porter Business MAU (L0) | % of Porter Business MAU aware of PTL | Amplitude → (no card id) | — | ◻️ unverified | `...#L169` |
| 4 | VSS Top-of-Funnel — PTL Serviceable Sessions (L1) | VSS sessions where route is PTL-serviceable | Amplitude → chart 3jh9upju | — | ◻️ unverified | `...#L170` |
| 5 | PTL Serviceable VSS as % of Overall Porter Sessions on VSS (L1) | % of VSS sessions PTL-serviceable | Amplitude → card 42065 | — | ◻️ unverified | `...#L171` |
| 6 | PTL Card Tap Rate in Serviceable Sessions (Business Users) (L1) | % serviceable business sessions w/ PTL card tap | Amplitude → card 49312 | — | ◻️ unverified | `...#L172` |
| 7 | PTL Selection Rate vs FTL (L1) | % of PTL+FTL sessions where PTL chosen | Amplitude → chart gjvatdh3 | — | ◻️ unverified | `...#L173` |
| 8 | Outstation Search Rate (Business Users) (L1) | % business openers searching >100km route | Amplitude → chart l9brfm70 | — | ◻️ unverified | `...#L174` |
| 9 | PTL Activation Rate — Business Users (First Order within 7 Days of Card View) (L0) | % new card viewers ordering within 7d | Snowflake → "Raw Data/production" (no card) | — | ◻️ unverified | `...#L179` |
| 10 | VSS to Quote Check Conversion — New Business Users (L1) | VSS→Quote-Check conv, new business | Snowflake → card 48923 | — | ◻️ unverified | `...#L180` |
| 11 | Quote Check to Order Placed Conversion — New Business Users (L1) | Quote-Check→Order conv, new business | Snowflake → card 44469 | — | ◻️ unverified | `...#L181` |
| 12 | New PTL Business Users Acquired per Month (First Order) (L1) | Count new business users (first order)/mo | Snowflake → card 48921 | `partload_application.orders` + `oms_public.customers` | ✅ confirmed-via-metadata | `...#L182` |
| 13 | Average Sessions Before First PTL Order — Business Users (L1) | Avg sessions before first order | Snowflake → card 48922 | — | ◻️ unverified | `...#L183` |
| 14 | Business Session Conversion Rate (Session to Order) (L0) | % business sessions → order | Snowflake → card 48491 | `partload_analytics.ptl_fe_events` + `orders` + `dim_customers` | ✅ confirmed-via-metadata | `...#L184` |
| 15 | Overall Session Conversion Rate (Session to Order) (L1) | % all sessions → order | Snowflake → card 48491 | same as #14 | ✅ confirmed-via-metadata | `...#L185` |
| 16 | VSS to Quote Check Conversion — All Business Users (L1) | VSS→Quote-Check conv, all business | Snowflake → card 48984 | — | ◻️ unverified | `...#L186` |
| 17 | Quote Check to Order Placed Conversion — All Business Users (L1) | Quote-Check→Order conv, all business | Snowflake → card 48984 | — | ◻️ unverified | `...#L187` |
| 18 | Median Time to Book (VSS to Order Placed) (L1) | Median VSS→order minutes | Amplitude → (no card) | — | ◻️ unverified | `...#L188` |
| 19 | Completed PTL Orders — Business Users (Monthly) (L0) | Count completed business orders/mo | Snowflake → card 33462 | `orders`/`order_vehicles` **UNION `gsheet_sync.ptl_offline_orders`** + `dim_customers` | ✅ confirmed · ⚠️ offline-union base (§3.3) | `...#L189` |
| 20 | Customer Rating / NPS — Business Users (L0) | Avg rating / NPS from business users | Survey / Freshdesk → "Sheets + Others" | — | ◻️ unverified · flag §5 | `...#L194` |
| 21 | Support Tickets per Order (L0) | Tickets raised / completed orders | Freshdesk → "Sheets + Others" | — | ◻️ unverified | `...#L195` |
| 22 | Support Ticket % (% of Orders Generating a Support Ticket) (L1) | % orders generating ≥1 ticket | Freshdesk → "Sheets + Others" | — | ◻️ unverified | `...#L196` |
| 23 | First Contact Resolution % (FCR) (L1) | % tickets resolved first contact | Freshdesk → "Sheets + Others" | — | ◻️ unverified | `...#L197` |
| 24 | Escalation % (% of Tickets Escalating to Social Media or Founder) (L1) | % tickets escalating to social/founder | Freshdesk / Manual → "Sheets + Others" | — | ◻️ unverified | `...#L198` |
| 25 | L4 Tickets (Social Media / Mystery Shopping / Support) (L1) | Count L4 escalation tickets/mo | Manual / Freshdesk → "Sheets + Others" | — | ◻️ unverified (review: NA) | `...#L199` |
| 26 | Total Fulfillment % (L0) | % placed orders completed (± <60s cancels) | Snowflake → dashboard 4198 | raw `partload_application` + `gsheet_sync`; embeds 33462/33461/33706 | ✅ confirmed · ⚠️ offline-union base (§3.3) | `...#L204` |
| 27 | Cancellation Attribution % — Customer / Porter / Partner (L1) | Cancels split by attribution | Snowflake → "Not found — may be embedded in dashboard/4793" (sheet's own note) | — | ⚠️ contradicted—conflict (no card + column-shift §3.8) | `...#L205` |
| 28 | CBDF % (Cancellation Before Driver Found) (L1) | % orders cancelled pre-allocation | Snowflake → dashboard 4793 | `orders`/`order_cancellation_reasons`/`order_vehicles` | ⚠️ contradicted—conflict (parallel defs §3.4) | `...#L206` |
| 29 | Customer / Porter Attributed CBDF % (L2) | CBDF split by attribution | Snowflake → card 49366 | `orders`/`order_cancellation_reasons`/`order_vehicles` | ⚠️ contradicted—conflict (§3.4; column-shift §3.8) | `...#L207` |
| 30 | CADF % (Cancellation After Driver Found) (L1) | % orders cancelled post-allocation | Snowflake → dashboard 4793 | as #28 | ⚠️ contradicted—conflict (§3.4; column-shift §3.8) | `...#L208` |
| 31 | Customer / Porter / Partner Attributed CADF % (L2) | CADF split by attribution | Snowflake → card 49366 | as #29 | ⚠️ contradicted—conflict (§3.4; column-shift §3.8) | `...#L209` |
| 32 | Perfect Order Experience % (L0) | % orders w/ on-time pickup+delivery, no damage/WD | Snowflake → "Sheets + Others" | — | ◻️ unverified · ⚠️ column-shift §3.8 | `...#L210` |
| 33 | On Time Pickup % + On Time Delivery % (L1) | % orders both on-time pickup & delivery | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: Apr corrupted) | `...#L211` |
| 34 | On Time Pickup % (L2) | % orders on-time pickup | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L212` |
| 35 | On Time Delivery % (L2) | % orders on-time delivery | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L213` |
| 36 | Damage % (L1) | % orders w/ customer damage report | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L214` |
| 37 | Orders with Weight Discrepancy % (L1) | % orders w/ weight discrepancy | Snowflake → card 36421 (**db108**) | `prod_eldoria.core.FACT_PTL_ORDERS` + `FACT_PTL_WD_LOGS` | ⚠️ contradicted—conflict (refs missing `route_name` §3.7; only governed-layer card) | `...#L215` |
| 38 | Effective Fulfilment % (L1) | completed / (placed − customer-attrib cancels) | Snowflake → card 48581 | `orders`/`order_cancellation_reasons`/`ptl_internal_users` | ✅ confirmed · ⚠️ offline **excluded** vs #26 (§3.3) | `...#L216` |
| 39 | M1 Business User Retention % (L0) | % M0 business users ordering in M+1 | Snowflake → dashboard 4569 | `oms_public.customers` + `partload_application.orders` | ✅ confirmed-via-metadata | `...#L221` |
| 40 | Repeat Rate (Business Users with ≥2 Lifetime PTL Orders) (L1) | % business users w/ ≥2 lifetime orders | Snowflake → card 39118 | `orders` + `oms_public.customers` **UNION `ptl_offline_orders`** | ✅ confirmed · ⚠️ offline-union (§3.3); column-shift §3.8 | `...#L222` |
| 41 | Share of Monthly Business Orders from Repeat Users (L2) | % monthly business orders from repeat users | Snowflake → card 39119 | `orders` + `oms_public.customers` (**online only**) | ✅ confirmed · ⚠️ base differs from #40 (§3.3) | `...#L223` |
| 42 | Avg Transactions per Business Customer per Month (L1) | Avg completed orders per active business user | Snowflake → card 44080 | — | ◻️ unverified | `...#L224` |
| 43 | Reactivation % (60+ Day Inactive Business Users) (L1) | % 60d-inactive business users ordering | Snowflake → card 48919 | — | ◻️ unverified (review: low base) | `...#L225` |
| 44 | Median Days Between Orders — Repeat Business Users (L1) | Median inter-order gap, repeat business | Snowflake → card 49311 | — | ◻️ unverified | `...#L226` |
| 45 | Share of Business Users on Overall Transacting Users (L1) | Business vs Personal share of transacting | Snowflake → card 39149 | — | ◻️ unverified | `...#L227` |
| 46 | Avg Orders per Trip (Clubbing Opportunity Trips) (L0) | orders / trips where ≥2 orders same route+date | Snowflake → card 33461 | `batched_orders_v1`/`order_vehicles`/`orders`/`slots` **UNION `ptl_offline_orders`** | ✅ confirmed · ⚠️ offline-union (§3.3) | `...#L232` |
| 47 | Vehicle Space Utilization % (Clubbing Opportunity Trips) (L1) | % capacity used on clubbing trips | Snowflake → card 43940 | `orders`/`load_details`/`order_fares`/`batch_v1`/`jobs`/`vehicles` + `gsheet_sync.ptl_table` | ✅ confirmed · ⚠️ hardcoded `created_at > '2025-07-11'` | `...#L233` |
| 48 | Batch Acceptance % by Partners (L1) | % batched assignments accepted by owners | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) | `...#L234` |
| 49 | Pickup / Delivery SLA Breach % due to Batching (Guardrail) (L1) | SLA breach attributable to batching | Snowflake → "Sheets + Others" | — | ◻️ unverified · ⚠️ column-shift §3.8 | `...#L235` |
| 50 | Allocation Acceptance Rate — Batches Accepted by Owners (L0) | % pinged batches accepted | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) | `...#L236` |
| 51 | Time to Allocate — P50 (minutes) (L1) | Median order-placed→vehicle-assigned mins | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L237` |
| 52 | % of Organic Allocation (No Manual Ops Intervention) (L1) | % orders allocated without ops touch | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA, engine Q3) | `...#L238` |
| 53 | Reallocation Rate (L1) | % orders reallocated after first assignment | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) | `...#L239` |
| 54 | GM% per PTL Order (L0) | (Revenue − Direct Costs) / Revenue per order | Snowflake / Finance → "Sheets"; `Status`=Finance | — | ◻️ unverified · ⚠️ Finance cross-thread; column-shift §3.8 (trend values in wrong cell) | `...#L244` |
| 55 | Average Order Value (AOV) (L1) | Revenue / completed orders | Snowflake → card 33706 | `partload_application.orders` + `ptl_routes` | ✅ confirmed · ⚠️ date-basis `updated_at` (§3.6); offline **excluded** | `...#L245` |
| 56 | Return Trip % (Porter-Arranged Return on Bidirectional Routes) (L1) | % return-eligible trips w/ arranged return | Snowflake → card 44691 | `orders`/`batched_orders_v1`/`order_vehicles`/`vehicles`/`service_zones` + `ptl_routes` | ✅ confirmed-via-metadata | `...#L246` |
| 57 | Monthly Active Owners (MAO) (L0) | Unique owners w/ ≥1 trip/mo | Snowflake → "Sheets" | — | ◻️ unverified | `...#L251` |
| 58 | New Owners Onboarded per Month (L1) | Count new owners/mo | Snowflake → "Sheets" | — | ◻️ unverified | `...#L252` |
| 59 | Monthly Active Vehicles (MAV) (L0) | Unique vehicles w/ ≥1 trip/mo | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L253` |
| 60 | New Vehicles Onboarded per Month (L1) | Count new vehicles/mo | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L254` |
| 61 | Owner Onboarding Activation Rate (1st Trip within 30 Days) (L1) | % new owners w/ trip in 30d | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L255` |
| 62 | Median Days from Owner Onboarding to First Trip (L1) | Median onboarding→first-trip days | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) | `...#L256` |
| 63 | M1 Owner Retention % (L0) | % M0 owners w/ trip in M+1 | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L257` |
| 64 | % Trips with On-Time Pickup (Owner/Supply View) (L1) | % trips on-time pickup, supply view | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L258` |
| 65 | % Trips with On-Time Delivery (Owner/Supply View) (L1) | % trips on-time delivery, supply view | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L259` |
| 66 | Owner Batch Acceptance Rate (Pings to Acceptance %) (L0) | % pinged batches accepted in window | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L264` |
| 67 | Owner Batch Completion Rate (Accepted to Completed %) (L0) | % accepted batches completed | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L265` |
| 68 | SLA Adherence % — On-Time Pickup + Delivery by Owner (L0) | % owner trips meeting both SLAs | Snowflake → "Sheets + Others" | — | ◻️ unverified | `...#L266` |
| 69 | Partner Attributed Damage % (L0) | % orders w/ owner/partner-attributed damage | Snowflake → "Sheets" | — | ◻️ unverified | `...#L267` |
| 70 | Owner Earnings per Trip (L0) | Avg owner payout (base+incentive) per trip | Snowflake / Finance → card 49316; `Status`=Finance | `partload_application.batch_v1` + `partload_analytics.vendor_payout_batch_level` | ✅ confirmed · ⚠️ `status=3` filter **commented out** (all batches counted); Finance cross-thread | `...#L268` |
| 71 | Trips per Monthly Active Vehicle (L1) | Completed trips / MAV | Snowflake → card 49313 | `orders`/`batched_orders_v1`/`order_vehicles` + `dim_customers` | ✅ confirmed · ⚠️ joins `customer_uuid=customer_id` (key drift §3.5) | `...#L269` |
| 75 | Owner Earnings per Monthly Active Vehicle (L0) | Owner earnings / MAV | Snowflake → "Sheets" | — | ◻️ unverified · ⚠️ column-shift-adjacent (blank def) | `...#L270` |
| 72 | Partner NPS (L0) | Owner/Partner NPS (%Prom − %Detr) | Survey → "Sheets" | — | ◻️ unverified (review: NA, no instrumentation) | `...#L275` |
| 73 | Partner Support Tickets per Trip % (L0) | Partner tickets / trips | Freshdesk / Manual → "Sheets" | — | ◻️ unverified · ⚠️ column-shift §3.8 | `...#L276` |
| 74 | Appsheet Adoption amongst Owners and Partners (L0) | % MAO+MAP using Appsheet for OLC | Appsheet Analytics → "Sheets + Others" | — | ◻️ unverified | `...#L277` |
| 76 | Uptime % — PartLoad-Ktor & PartLoad-Job Servers (L0) | % uptime of Ktor+Job servers/mo | DataDog; `Status`=Core Platforms | — | ◻️ unverified · flag §5 ("Tech defined metrics not sre about these") | `...#L282` |
| 77 | Latency P95 — PartLoad-Ktor & PartLoad-Job Servers (L1) | P95 latency ms | DataDog; Core Platforms | — | ◻️ unverified | `...#L283` |
| 78 | Booking Details Page Load Latency P95 (L2) | P95 page-load ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L284` |
| 79 | Check Serviceability API Latency P95 (L2) | P95 API latency ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L285` |
| 80 | Quote Generation API Latency P95 (L2) | P95 API latency ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L286` |
| 81 | Booking Creation API Latency P95 (L2) | P95 API latency ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L287` |
| 82 | Error Rate — PartLoad-Ktor & PartLoad-Job Servers (L1) | % server requests erroring | DataDog; Core Platforms | — | ◻️ unverified | `...#L288` |
| 83 | Booking Details Page Load Error Rate (L2) | % page-load errors | DataDog; Core Platforms | — | ◻️ unverified · ⚠️ column-shift §3.8 | `...#L289` |
| 84 | Check Serviceability API Error Rate (L2) | % API errors | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L290` |
| 85 | Quote Generation API Error Rate (L2) | % API errors | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L291` |
| 86 | Booking Creation API Error Rate (L2) | % API errors | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) | `...#L292` |

`...` = `repo@7a43470:ptl-selfserve/iteration-1-ptl-metric-catalog.md`

**Doc's own coverage tally** (corrected 2026-07-23 pass): "✅ confirmed-via-metadata: **15** (#12,14,15,19,26,38,39,40,41,46,47,55,56,70,71); ⚠️ contradicted—conflict: **6** (#27,28,29,30,31,37); ◻️ unverified: **64** (15 + 6 + 64 = 85)." — `repo@7a43470:ptl-selfserve/iteration-1-ptl-metric-catalog.md#L294-297`. "the headline count is **7 conflicts + 1 data-entry flag**" (item 8 in §3, the column-shift, is flag F18 not a source-of-truth conflict) — `...#L297-301`.

### Verbatim uncertainty flags register (F1–F18)
Full table at `repo@7a43470:ptl-selfserve/iteration-1-ptl-metric-catalog.md#L310-329`. Selected verbatim entries (all "None resolved" per doc, `...#L308`):
- F1: "Blank for all 85 rows — the sheet records no governed-asset status for any metric." (`Does Eldoria have underlying asset?` column) — `#L312`
- F2: "Blank for all 85 rows — no v1 scope declared in the sheet." (`Important for v1` column) — `#L313`
- F9 (#27): "Not found — may be embedded in dashboard/4793" — `#L320`
- F11 (#54, GM%): `Status`="Finance"; cross-thread="Finance"; trend text in wrong cell: "Mar-26: -73.5%; Jan-26: -160.8%; Oct-25: -127.6%" — `#L322`
- F15: "`semantic_model.porter.fact_ptl_orders` exposes **0 measures**; `list_metrics` returns **0** PTL/partload metrics." — `#L326`
- F16: "Card 36421 filters on `route_name`, absent from `fact_ptl_orders` (join commented out) — latent break." — `#L327`
- F17: "State enum (3=completed, 4=cancelled) **inferred from SQL, not confirmed** against a data dictionary." — `#L328`
- F18: "Column-shifted in the sheet; cells carried as-is (values ~2 cols right of intent)." (rows #27,29,30,31,40,49,73,83) — `#L329`

---

## Business context

| Fact | Citation |
|---|---|
| Iteration 1 was prepared 2026-07-09 by akshay.jain@theporter.in; repo `akshayjain00/selfserve_data`. Architecture principles "carried verbatim from the PnM engagement (closed-world registry + deterministic read-only engine + AI as translator/investigator/narrator only — the AI never authors SQL)." | `iteration-1-ptl-metric-catalog.md#L3-7` |
| The May'26 PTL Product Ops Review (Notion) is "a dense 4-table funnel of 73 metrics with 7-month trends and per-metric commentary" — the task premise of "narrative-heavy, almost no structured metrics" does NOT hold. | `iteration-1-ptl-metric-catalog.md#L34-38` |
| Review structure has 4 number-bearing sections + 1 narrative: Product Context (0 metrics, NARRATIVE-ONLY, "5 bullets: pre-PMF, ops-assisted, Appsheet partner OLC"), North Star callout (NARRATIVE), Demand (38 metrics), Marketplace (15 metrics), Supply (18 metrics), Health (4 metrics). | `iteration-1-ptl-metric-catalog.md#L121-130` |
| PTL is described in the review's own Product Context bullets as "pre-PMF, ops-assisted," with an "Appsheet partner OLC." | `iteration-1-ptl-metric-catalog.md#L125` |
| The doc titled "May'26" review actually shows Apr-26 as its latest data column: "latest column = Apr-26 despite 'May'26' title." | `iteration-1-ptl-metric-catalog.md#L121` |
| Apr-26 headline values cited: NSM 2247; NPS 53.85; activation 2.5%; completed orders (business) 3341; FF 56% / excl-60s 66%; CBDF 30%; CADF 13.81%; avg orders/trip 1.59; GM% −78.28%; AOV 2920; MAV 739; trips/MAV 6.2; SLA adherence 50.6%; earnings/trip 12579; Uptime SLO 99.9%; Ktor err 0.0005%; latency P95 15.22ms; L4 tickets NA. | `iteration-1-ptl-metric-catalog.md#L127-130` |
| Blank/NA spots in the review "because the product doesn't exist yet or isn't instrumented": batch acceptance rate, % organic allocation, reallocation rate ("batching engine targeted Q3"), Partner NPS, L4 tickets, median days onboarding→first trip, and April on-time pickup/delivery ("source flagged corrupted"). | `iteration-1-ptl-metric-catalog.md#L132-135` |
| Sheet-only superset not in the May'26 review: Platform Health API-level rows #78–#86 (Booking Details / Check-Serviceability / Quote-Generation / Booking-Creation latency & error rates) — "design-catalog aspirations, not currently reviewed." | `iteration-1-ptl-metric-catalog.md#L137-140` |
| No section literally called "Business Viability" exists in the review; viability metrics (GM%, AOV, owner earnings) sit inside Marketplace/Supply and "are populated, not blank" — described as contra "the Argus plan's 'entirely blank Business Viability section'" (Argus plan is an external reference, not one of the 3 pinned docs). No "Monthly Pulse (Happy/Concerned/Expect)" narrative block exists either. | `iteration-1-ptl-metric-catalog.md#L142-146` |
| Raw physical order-lifecycle tables (schema `prod_curated.partload_application`): `orders` (`id`, `external_id`=CRN, `state`, `estimated_fare`, `route_id`, `customer_mobile`, pickup/drop coords — "no allocation/cancellation cols on the order row"), `order_cancellation_reasons`, `order_vehicles` (allocation signal — "vehicle present ⇒ post-allocation"), `batched_orders_v1`/`batch_v1`/`jobs` (trip/batch), `load_details`, `order_fares`. Plus `partload_analytics.ptl_internal_users` (~53 test mobiles, "standard exclusion"), `ptl_routes`, `ptl_fe_events` (funnel), and `prod_curated.gsheet_sync.ptl_offline_orders` (manually-tracked offline orders). | `iteration-1-ptl-metric-catalog.md#L71-77` |
| Order state enum is "Inferred (UNVERIFIED): 3 = completed, 4 = cancelled, 0/1/2 = in-process — confirm against a data dictionary before trusting any completed/cancelled count." | `iteration-1-ptl-metric-catalog.md#L78-79` |
| Customer Business/Personal classification model: `frequency IN (1,2,3,4)`, read from two different tables depending on card (`prod_curated.oms_public.customers` in some, `prod_eldoria.core.dim_customers` in others), with join key also differing — most join on `customer_mobile`, but card 49313 joins `dim_customers.customer_uuid = orders.customer_id`. | `iteration-1-ptl-metric-catalog.md#L101-104` |
| Governed layer verdict: "PARTIALLY governed." Present & governed: `fact_ptl_orders`, `fact_ptl_wd_logs` (1 measure), `mart.mart_ptl_invoices` (CP_FINANCE_PRODUCT), `mart.ptl_outstation_dropoff` (NI_PTL). Missing/ungoverned: measures on the fact, and any cancellation/allocation/leads/trip model. Only card 36421 (weight discrepancy) runs on the governed layer, and it has a latent break. | `iteration-1-ptl-metric-catalog.md#L65-69` |
| Two Metabase database connections in play: card 36421 → db108; all other verified cards → db73 — same warehouse but different Metabase connections, unconfirmed whether they resolve to the same Snowflake account/role. | `iteration-1-ptl-metric-catalog.md#L89-91` |
| Glossary/jargon expansions found in-doc: NSM = North Star (Metric) callout naming; CBDF = "Cancellation Before Driver Found"; CADF = "Cancellation After Driver Found"; AOV = "Average Order Value"; MAV = "Monthly Active Vehicles"; MAO = "Monthly Active Owners"; FCR = "First Contact Resolution %"; WD = weight discrepancy (`FACT_PTL_WD_LOGS`); GM% formula = "(Revenue − Direct Costs) / Revenue per order"; L4 Tickets = "Social Media / Mystery Shopping / Support" escalation tier. | catalog rows #2,26,28,30,55,57,59,23,37,54,25 — see inventory table above |
| Jargon used but NOT expanded anywhere in the 3 docs (flag, not resolved): VSS ("VSS Top-of-Funnel", "VSS sessions" — Amplitude funnel-stage term), OLC ("Appsheet partner OLC"; "% MAO+MAP using Appsheet for OLC"), MAP (used alongside MAO in row #74, expansion not stated), CRN (`orders.external_id`=CRN, not expanded). | `iteration-1-ptl-metric-catalog.md#L170,174,125,277,72` |
| NPS methodology "changed mid-April (Sean Ellis → promoter-minus-detractor)"; this is a trend-continuity break in the source, not an artifact of the self-serve build. | `iteration-1-ptl-journey-proposal.md#L83-84` |
| The `ptl_internal_users` (~53 test mobiles) exclusion "is applied inconsistently across cards." | `iteration-1-ptl-journey-proposal.md#L78-79` |
| Multi-source composition of the 85-row catalog: "only ~40 are Snowflake; the rest are Amplitude (5), Freshdesk/Survey/Manual (≈15), DataDog (11), Finance (2), and 'Sheets + Others' manual (many)." | `iteration-1-ptl-journey-proposal.md#L63-66` |
| `fact_ptl_orders` is owned by CATEGORY_ANALYTICS, not the PTL team (NI_PTL) — "any 'make it governed' path is a cross-team negotiation." | `iteration-1-ptl-journey-proposal.md#L72-73` |
| Cross-vertical metric-name collisions flagged: "CBDF, CADF, allocation %, FF, uptime all collide by name with HCV and Allocation" (referred to as unsolved "Argus B-002"). | `iteration-1-ptl-journey-proposal.md#L74-77` |

---

## Open questions / blind spots

### A. Ranked top open questions (journey proposal §A — "only you can answer these," ranked by architecture impact)

**Q0 (added later, F.5, "prepend to §A") — Consumption model & cadence:** "generated monthly review doc (Notion), live ad-hoc queries, or both? May re-order the entire journey. (Only you can answer.)" — `iteration-1-ptl-journey-proposal.md#L253-254`

**Q1 — Source path: build on RAW `partload_application`, or push for the GOVERNED layer? ⟶ changes everything**
- "(A) Prototype on raw `partload_application`, bug-for-bug with the chosen dashboards — RECOMMENDED (~75%)."
- "(B) Push CATEGORY_ANALYTICS to add measures + build governed cancellation/allocation models first (~25%)."
- "Why only you: it commits (or doesn't commit) another team's effort, and it's a program-level bet."
- `iteration-1-ptl-journey-proposal.md#L14-22`

**Q2 — Offline-order base: do PTL numbers include the manual `gsheet_sync.ptl_offline_orders`? ⟶ changes every ratio**
- "My lean: one base, applied everywhere — most likely 'include offline' since PTL is operationally-assisted and offline is real GMV, but ~55%; genuinely your call."
- "Why only you: it's a business definition of 'what counts as a PTL order,' not a data fact."
- `iteration-1-ptl-journey-proposal.md#L24-30`

**Q3 — North Star: "Monthly Transacting Business Customers" or "30-day repeat rate"? ⟶ anchors the whole review**
- "Why only you: reconciling your own two source documents; I won't pick silently. Confidence I've stated the conflict correctly: 95%."
- `iteration-1-ptl-journey-proposal.md#L32-35`

**Q4 — Cancellation canonical definition: dashboard 4793 or card 49366? ⟶ core Marketplace metric**
- "Why only you: picking the canonical operational definition is an owner/analytics-lead ruling."
- `iteration-1-ptl-journey-proposal.md#L37-40`

**Q5 — v1 scope: which metrics are in the first governed bundle? ⟶ scopes iteration 2**
- "The sheet's `Important for v1` column is blank for all 85 rows (catalog F2). I recommend the Snowflake-backed Marketplace + Demand core (~12 metrics: NSM, completed orders, FF, effective FF, CBDF, CADF, avg-orders/trip, AOV, session conversion, new business users, M1 retention, time-to-allocate) — the intersection of 'in the May review,' 'Snowflake-sourced,' and 'named in the Argus PTL bundle.' Confidence this is the right v1 cut: 70%."
- `iteration-1-ptl-journey-proposal.md#L42-48`

**Secondary (stated as: "I can progress without these, but they'll bite")**
- (a) "MTD-vs-locked-month cadence — the 'May'26' doc reviews Apr data; is the review always 'last completed month'?"
- (b) "Are Finance-owned (GM%, owner earnings) and Core-Platforms-owned (DataDog health) metrics in scope for ProdOps self-serve, or federated out?"
- (c) "Who is the audience, and what triggers 'open to stakeholders'?"
- `iteration-1-ptl-journey-proposal.md#L50-54`

### B. Blind-spot pass (journey proposal §B — ranked by architecture impact)

1. "PTL is multi-source; PnM was single-source. This is the biggest divergence... Any plan that implies the engine 'answers the review' is wrong unless it also states what it can't answer." — `#L62-67`
2. "A large slice of the review isn't in any queryable DB — it's manual sheets, or no product yet... De-manualizing those isn't a data task; it's a product/eng ask." — `#L68-71`
3. "You don't own the governed fact. `fact_ptl_orders` is CATEGORY_ANALYTICS's, not NI_PTL's. Any 'make it governed' path is a cross-team negotiation — schedule and control risk, not code." — `#L72-73`
4. "Cross-vertical collision (Argus B-002) is sharper for PTL than for PnM... argues for forking, not generalizing, now (§D)." — `#L74-77`
5. "Denominator/exclusion landmines beyond offline orders" — inconsistent internal-user exclusion, dual customer-classification source+join-key, AOV date-basis mismatch — "will silently mis-stack months." — `#L78-82`
6. "Trend continuity is already broken in the source" — NPS methodology change mid-April; April on-time pickup/delivery flagged corrupted — "must annotate discontinuities, or it will look like a real move." — `#L83-85`
7. "'May'26' reviews April data. Whatever cadence you pick, the month-basis... must be explicit in the registry, or MTD-vs-locked-month drift creeps in (a house-rule tripwire)." — `#L86-88`
8. "The premise inversion changes the pitch... Frame the CTO story on trust + de-manualization, not on structuring." — `#L89-92`

### Maker-Checker addendum open item (F.5, new)
"Q0 (new, prepend to §A) — Consumption model & cadence: generated monthly review doc (Notion), live ad-hoc queries, or both? May re-order the entire journey. (Only you can answer.)" — `iteration-1-ptl-journey-proposal.md#L253-254` (duplicate of Q0 above; listed once there and once here in source doc, both citations given for traceability.)

---

## Conflicts found

**CONFLICT: v1 bundle metric count/composition (12 vs 11), specifically Time-to-Allocate P50 (#51)**
- Side 1 (journey proposal, dated 2026-07-09, §E "Proposed v1 registry shortlist"): lists **12** metrics — "NSM Monthly Transacting Business Customers (#2), Completed Orders–Business (#19), Total FF (#26), Effective FF (#38), CBDF (#28), CADF (#30), Avg Orders/Trip–clubbing (#46), AOV (#55), Business Session Conversion (#14), New Business Users (#12), M1 Business Retention (#39), **Time to Allocate P50 (#51, pending a card/source)**." Citation: `iteration-1-ptl-journey-proposal.md#L160-166`. Also §A Q5 text says "~12 metrics" including "time-to-allocate" — `iteration-1-ptl-journey-proposal.md#L44-46`.
- Side 2 (DECISION_LOG D6, owner ruling dated 2026-07-23): locks v1 at **11** metrics, explicitly the same list minus #51 — "**Deferred:** Time-to-Allocate P50 → iteration 2.5 (source is a manual sheet, no verified card — would drag v1 trust down)." Citation: `DECISION_LOG.md#L42-45`.
- UNRESOLVED (in the sense that this extract does not adjudicate which supersedes — noted here only because the two source documents literally disagree on the v1 count/composition; per the task framing D6 is later-dated and self-labeled as an owner ruling, but this extract does not pick a side).

**CONFLICT: total unverified-row count (~62 vs 64)**
- Side 1 (journey proposal, iteration-1 self-assessment): "Confidence complete & faithful: 90% (the −10% is the **~62 unverified rows** and the unconfirmed state enum)." Citation: `iteration-1-ptl-journey-proposal.md#L112-113`.
- Side 2 (metric catalog's own corrected tally, post-2026-07-23 verification pass, and DECISION_LOG's Drift 2): "◻️ unverified: **64**" — catalog explicitly flags that an earlier tally of "17/6/62" was a mis-statement now corrected to "15 confirmed / 6 contradicted / 64 unverified." Citations: `iteration-1-ptl-metric-catalog.md#L294-297`; `DECISION_LOG.md#L92-93` ("Drift 2 (fixed): headline status tally is 15 confirmed / 6 contradicted / 64 unverified, not 17/6/62").
- UNRESOLVED — the journey-proposal file's own text was not updated after the 2026-07-23 verification pass corrected the catalog and decision log; the "~62" figure in the journey file and the "64" figure in the (now-corrected) catalog/decision-log stand side by side in the pinned commit.

No other direct document-vs-document (as opposed to catalog-internal, card-vs-card) disagreements were found across DECISION_LOG.md, the metric catalog, and the journey proposal at commit `7a43470`. All catalog-internal source-of-truth conflicts (offline-order base, dual cancellation definitions, customer-classification source/join-key drift, AOV date-basis, governed-card route_name break, column-shifted sheet rows, NSM-vs-Argus-plan naming) are carried in the Metric catalog inventory / Business context sections above with their own citations, since catalog, journey, and DECISION_LOG describe those consistently with each other (the journey and catalog surface them; DECISION_LOG rules on some of them) rather than contradicting one another.
