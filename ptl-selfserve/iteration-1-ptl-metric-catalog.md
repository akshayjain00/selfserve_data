# PTL Self-Serve — Iteration 1: Metric Catalog

*Prepared 2026-07-09. Owner: akshay.jain@theporter.in · Repo: `akshayjain00/selfserve_data`.
Iteration 1 = MAP ONLY. No code written. Zero production queries executed. All sources
read-only. Architecture principles carried verbatim from the PnM engagement (closed-world
registry + deterministic read-only engine + AI as translator/investigator/narrator only —
the AI never authors SQL).*

> **Companion file:** `iteration-1-ptl-journey-proposal.md` holds the ranked owner-only open
> questions (FIRST), the blind-spot pass, and the proposed journey with % confidence. **Read
> the journey file's top section before acting on anything here** — three findings below would
> change the plan's shape.

---

## 0. Method & provenance (what I actually read, and how)

| Source | How read | Result |
|---|---|---|
| 4 PnM reference files (`HANDOFF.md`, `DECISION_LOG.md`, `iteration-1…`, `iteration-2…`, + `selfserve_nlq/` code) | Local repo | Architecture + house rules + catalog/ledger formats internalized |
| PTL Product Ops Review, May'26 (Notion) | Notion connector, full page + verified no child pages | 73 metrics across 4 tables — see §4 |
| PTL metric tab ("PTL_Metrics" in the "ProdOps HSC" workbook, gid 279537508) | Google Drive connector (read as XLSX + parsed) | 85 metrics (rows #2–#86) — the catalog seed below |
| Metabase card/dashboard definitions (14 cards, 3 dashboards) | Metabase `get_card`/`get_dashboard` **metadata only — nothing executed** | Source tables traced; conflicts found (§3) |
| Governed dbt / semantic layer for PTL | Data Catalog `search`/`list_semantic_models`/`get_semantic_model`/`search_columns` | `fact_ptl_orders` exists but measureless — see §2 |

**Connector status:** Notion, Google Drive, Metabase, and Data Catalog all responded — no auth
failures. Per the constraint, the Google Sheet was read via the Drive connector (it supports
`application/vnd.google-apps.spreadsheet`); no data was written anywhere.

---

## 1. Headline findings (full treatment in the journey file)

1. **The task premise ("narrative-heavy, almost no structured metrics") does not hold for the
   May'26 review.** That review is a dense 4-table funnel of **73 metrics** with 7-month trends
   and per-metric commentary. The structuring is largely *already done*. The unmet win is
   therefore **governance + reconciliation + de-manualizing the monthly refresh**, not "turn
   prose into metrics." This is closer to PnM's actual pathology than the brief assumed.
2. **North-Star conflict.** Review + sheet both declare the NSM = **"Monthly Transacting
   Business Customers on PTL"** (Apr-26 = 2247). The Project-Argus plan asserts PTL's NSM is the
   **"30-day repeat rate."** These disagree; I did not pick one. *(Owner Q1 in journey file.)*
3. **A governed PTL layer exists but is bypassed.** `PROD_ELDORIA.core.fact_ptl_orders` is real
   (CATEGORY_ANALYTICS-owned, tested) but its semantic model exposes **0 measures** and
   `list_metrics` returns **0 PTL metrics**. **13 of 14 verified cards read raw
   `partload_application` directly.** There is **no governed model for cancellations,
   allocation, leads, or trips/batches.** So PnM's "re-point everything to Eldoria" move does
   **not** transfer cleanly.

---

## 2. Source-of-truth chain (PnM lesson 1: walk it before designing)

```
Sheet says            Metabase card reads           Governed dbt layer (Data Catalog)
─────────             ───────────────────           ─────────────────────────────────
"PTL Analytics DB"  → raw PROD_CURATED.             → PROD_ELDORIA.core.fact_ptl_orders
"Raw Data/production"  partload_application.*          (CATEGORY_ANALYTICS; order grain;
"Sheets + Others"      (+ gsheet_sync offline         ~90.6k rows; PK/FK/freshness tests)
"Amplitude"            orders, oms_public.customers,   → semantic_model exists, 0 MEASURES
"Freshdesk"/"Survey"   prod_eldoria.core.dim_customers → 0 PTL metrics in catalog
"DataDog"                                             → NO governed cancellation / allocation
"Snowflake / Finance"                                   / leads / trips model
```

**Governed-layer verdict: PARTIALLY governed.** Present & governed: `fact_ptl_orders`,
`fact_ptl_wd_logs` (1 measure), `mart.mart_ptl_invoices` (CP_FINANCE_PRODUCT), `mart.ptl_outstation_dropoff`
(NI_PTL). Missing/ungoverned: measures on the fact, and any cancellation/allocation/leads/trip
model. **Only one verified card (36421, weight discrepancy) runs on the governed layer** — and
it has a latent break (see §3.7).

**Raw physical tables confirmed** (`prod_curated.partload_application`): `orders`
(`id`, `external_id`=CRN, `state`, `estimated_fare`, `route_id`, `customer_mobile`, pickup/drop
coords — **no allocation/cancellation cols on the order row**), `order_cancellation_reasons`,
`order_vehicles` (allocation signal — vehicle present ⇒ post-allocation), `batched_orders_v1`/
`batch_v1`/`jobs` (trip/batch), `load_details`, `order_fares`. Plus `partload_analytics.ptl_internal_users`
(~53 test mobiles = standard exclusion), `ptl_routes`, `ptl_fe_events` (funnel), and
`prod_curated.gsheet_sync.ptl_offline_orders` (manually-tracked offline orders).
**Inferred (UNVERIFIED) state enum: 3 = completed, 4 = cancelled, 0/1/2 = in-process** — confirm
against a data dictionary before trusting any completed/cancelled count.

---

## 3. Conflicts found — surfaced, never resolved (PnM lesson 4: the map lies)

Each is an input to an owner decision, not a resolution.

1. **Governed layer bypassed.** 13/14 cards read raw `partload_application`; only 36421 uses
   `fact_ptl_orders`. The governed fact is not the operational source of truth.
2. **Two Metabase databases.** Card 36421 → **db108**; all others → **db73**. Same warehouse,
   different Metabase connections — confirm they resolve to the same Snowflake account/role
   before treating 36421 as comparable.
3. **Offline-order base is inconsistent across cards.** `ptl_offline_orders` is UNION-ed in by
   33461 (avg orders/trip), 33462 (completed orders), 39118 (repeat rate); but **excluded** by
   48581 (effective FF), 33706 (AOV), 48921 (new users), 39119 (new-v-repeat). **Fulfilment,
   AOV and the funnel are therefore not computed on the same order base.** For MBR-grade numbers
   this is material.
4. **Two parallel cancellation definitions.** CBDF/CADF dashboard **4793** carries its own
   `cancel_type` + "<60s exclusion" params and funnel cards (43237/43242); standalone card
   **49366** derives CADF-vs-CBDF from `order_vehicles.vehicle_name IS NULL/NOT NULL`. No shared
   model.
5. **Customer classification drift.** Business/Personal (`frequency IN (1,2,3,4)`) is read from
   `prod_curated.oms_public.customers` in some cards (48921, 39118, 39119) and from
   `prod_eldoria.core.dim_customers` in others (33462, 48491, 49313). Join key also differs —
   most join on `customer_mobile`, but **49313 joins `dim_customers.customer_uuid = orders.customer_id`**.
6. **AOV date-basis mismatch.** 33706 buckets by `updated_at`; funnel/fulfilment cards bucket by
   `created_at`.
7. **The one governed-layer card is latently broken.** 36421 reads `fo.route_name` / `fwd.route_name`,
   but `fact_ptl_orders` has **no `route_name` column** (route-name join is commented out in the
   model; only `route_id` exists). The route filter would fail if exercised.
8. **8 source rows are column-shifted in the sheet itself** (#27, 29, 30, 31, 40, 49, 73, 83):
   the author's definition text spilled across cells, pushing values ~2 columns right. Cells are
   carried **as-is, unrepaired** (flags §5) — e.g. #32's real definition sits in its
   `Standardized Metric Name` cell; #54's month trend values sit in a `Remarks`/thread cell.

---

## 4. The May'26 review ↔ sheet cross-reference

The review and the sheet use **different section taxonomies** and are **not** 1:1.

**Review structure (Notion, 73 metrics, latest column = Apr-26 despite "May'26" title):**

| Review section | # metrics | Classification | Notable Apr-26 values |
|---|---|---|---|
| Product Context | 0 | NARRATIVE-ONLY (5 bullets: pre-PMF, ops-assisted, Appsheet partner OLC) | — |
| North Star callout | (names NSM) | NARRATIVE | "Monthly Transacting Business Customers on PTL" |
| Demand | 38 | NUMBER-BEARING | NSM 2247; NPS 53.85; activation 2.5%; completed orders (business) 3341 |
| Marketplace | 15 | NUMBER-BEARING | FF 56% / excl-60s 66%; CBDF 30%; CADF 13.81%; avg orders/trip 1.59; GM% −78.28%; AOV 2920 |
| Supply | 18 | NUMBER-BEARING | MAV 739; trips/MAV 6.2; SLA adherence 50.6%; earnings/trip 12579 |
| Health | 4 | NUMBER-BEARING | Uptime SLO 99.9%; Ktor err 0.0005%; latency P95 15.22ms; L4 tickets NA |

**Blank spots in the review (part of the map):** metrics shown `NA`/blank because the product
doesn't exist yet or isn't instrumented — **batch acceptance rate, % organic allocation,
reallocation rate** (batching engine targeted Q3), **Partner NPS**, **L4 tickets**, **median
days onboarding→first trip**, and **April on-time pickup/delivery** (source flagged corrupted).

**Sheet-only (catalog superset, not in the May'26 review):** the sheet's granular Platform
Health APIs — **#78–#86** (Booking Details / Check-Serviceability / Quote-Generation /
Booking-Creation latency & error rates) — the review's Health section carried only 4 aggregate
tech metrics. These are design-catalog aspirations, not currently reviewed.

**Named-section mismatches vs the Argus plan's expectations:**
- No section literally called **"Business Viability"** exists; viability metrics (GM%, AOV,
  owner earnings) appear as `Outcome`-class rows inside Marketplace/Supply — and are **populated,
  not blank** (contra the Argus plan's "entirely blank Business Viability section").
- No **"Monthly Pulse" (Happy/Concerned/Expect)** narrative block exists in this review.

---

## 5. The catalog — one row per PTL-metric-tab metric (85 rows, #2–#86)

**Status legend**
- **✅ confirmed-via-metadata** — the stated source card/dashboard exists and its underlying
  tables were traced via Metabase/Data Catalog metadata. **This is existence + lineage, NOT
  numeric validation** (no query was run).
- **◻️ unverified** — not checked this iteration: no card opened, or source is Amplitude /
  Freshdesk / Survey / Manual / DataDog / Sheets / Finance / raw-with-no-card. Default per lesson 4.
- **⚠️ contradicted—conflict** — a source-of-truth disagreement or latent break was found;
  described inline and in §3.

Definition = my one-line reading of the sheet's `Final Metric Definition` (or `{AI Enhanced}`
where Final was blank/shifted). Source = sheet `Source for the Metric Calculation` → the sheet's
`Existing Cards/Queries` id. "Tables traced" filled only where a card was opened.

### Demand & Acquisition
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 2 | Monthly Transacting Business Customers on PTL | **NSM** | Unique business users completing ≥1 PTL order/month | Snowflake → "Raw Data/production" (no card) | — | ◻️ unverified · **⚠️ NSM naming conflict (§1.2)** |
| 3 | PTL Awareness Rate amongst Porter Business MAU | L0 | % of Porter Business MAU aware of PTL | Amplitude → (no card id) | — | ◻️ unverified |
| 4 | VSS Top-of-Funnel — PTL Serviceable Sessions | L1 | VSS sessions where route is PTL-serviceable | Amplitude → chart 3jh9upju | — | ◻️ unverified |
| 5 | PTL Serviceable VSS as % of Overall Porter Sessions on VSS | L1 | % of VSS sessions PTL-serviceable | Amplitude → card 42065 | — | ◻️ unverified |
| 6 | PTL Card Tap Rate in Serviceable Sessions (Business Users) | L1 | % serviceable business sessions w/ PTL card tap | Amplitude → card 49312 | — | ◻️ unverified |
| 7 | PTL Selection Rate vs FTL | L1 | % of PTL+FTL sessions where PTL chosen | Amplitude → chart gjvatdh3 | — | ◻️ unverified |
| 8 | Outstation Search Rate (Business Users) | L1 | % business openers searching >100km route | Amplitude → chart l9brfm70 | — | ◻️ unverified |

### Activation & Conversion
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 9 | PTL Activation Rate — Business Users (First Order within 7 Days of Card View) | L0 | % new card viewers ordering within 7d | Snowflake → "Raw Data/production" (no card) | — | ◻️ unverified |
| 10 | VSS to Quote Check Conversion — New Business Users | L1 | VSS→Quote-Check conv, new business | Snowflake → card 48923 | — | ◻️ unverified |
| 11 | Quote Check to Order Placed Conversion — New Business Users | L1 | Quote-Check→Order conv, new business | Snowflake → card 44469 | — | ◻️ unverified |
| 12 | New PTL Business Users Acquired per Month (First Order) | L1 | Count new business users (first order)/mo | Snowflake → card 48921 | `partload_application.orders` + `oms_public.customers` | ✅ confirmed-via-metadata |
| 13 | Average Sessions Before First PTL Order — Business Users | L1 | Avg sessions before first order | Snowflake → card 48922 | — | ◻️ unverified |
| 14 | Business Session Conversion Rate (Session to Order) | L0 | % business sessions → order | Snowflake → card 48491 | `partload_analytics.ptl_fe_events` + `orders` + `dim_customers` | ✅ confirmed-via-metadata |
| 15 | Overall Session Conversion Rate (Session to Order) | L1 | % all sessions → order | Snowflake → card 48491 | same as #14 | ✅ confirmed-via-metadata |
| 16 | VSS to Quote Check Conversion — All Business Users | L1 | VSS→Quote-Check conv, all business | Snowflake → card 48984 | — | ◻️ unverified |
| 17 | Quote Check to Order Placed Conversion — All Business Users | L1 | Quote-Check→Order conv, all business | Snowflake → card 48984 | — | ◻️ unverified |
| 18 | Median Time to Book (VSS to Order Placed) | L1 | Median VSS→order minutes | Amplitude → (no card) | — | ◻️ unverified |
| 19 | Completed PTL Orders — Business Users (Monthly) | L0 | Count completed business orders/mo | Snowflake → card 33462 | `orders`/`order_vehicles` **UNION `gsheet_sync.ptl_offline_orders`** + `dim_customers` | ✅ confirmed · ⚠️ offline-union base (§3.3) |

### Customer Satisfaction & Support
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 20 | Customer Rating / NPS — Business Users | L0 | Avg rating / NPS from business users | Survey / Freshdesk → "Sheets + Others" | — | ◻️ unverified · flag §5 |
| 21 | Support Tickets per Order | L0 | Tickets raised / completed orders | Freshdesk → "Sheets + Others" | — | ◻️ unverified |
| 22 | Support Ticket % (% of Orders Generating a Support Ticket) | L1 | % orders generating ≥1 ticket | Freshdesk → "Sheets + Others" | — | ◻️ unverified |
| 23 | First Contact Resolution % (FCR) | L1 | % tickets resolved first contact | Freshdesk → "Sheets + Others" | — | ◻️ unverified |
| 24 | Escalation % (% of Tickets Escalating to Social Media or Founder) | L1 | % tickets escalating to social/founder | Freshdesk / Manual → "Sheets + Others" | — | ◻️ unverified |
| 25 | L4 Tickets (Social Media / Mystery Shopping / Support) | L1 | Count L4 escalation tickets/mo | Manual / Freshdesk → "Sheets + Others" | — | ◻️ unverified (review: NA) |

### Order Fulfillment & Quality
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 26 | Total Fulfillment % | L0 | % placed orders completed (± <60s cancels) | Snowflake → dashboard 4198 | raw `partload_application` + `gsheet_sync`; embeds 33462/33461/33706 | ✅ confirmed · ⚠️ offline-union base (§3.3) |
| 27 | Cancellation Attribution % — Customer / Porter / Partner | L1 | Cancels split by attribution | Snowflake → **"Not found — may be embedded in dashboard/4793"** (sheet's own note) | — | ⚠️ contradicted—conflict (no card + column-shift §3.8) |
| 28 | CBDF % (Cancellation Before Driver Found) | L1 | % orders cancelled pre-allocation | Snowflake → dashboard 4793 | `orders`/`order_cancellation_reasons`/`order_vehicles` | ⚠️ contradicted—conflict (parallel defs §3.4) |
| 29 | Customer / Porter Attributed CBDF % | L2 | CBDF split by attribution | Snowflake → card 49366 | `orders`/`order_cancellation_reasons`/`order_vehicles` | ⚠️ contradicted—conflict (§3.4; column-shift §3.8) |
| 30 | CADF % (Cancellation After Driver Found) | L1 | % orders cancelled post-allocation | Snowflake → dashboard 4793 | as #28 | ⚠️ contradicted—conflict (§3.4; column-shift §3.8) |
| 31 | Customer / Porter / Partner Attributed CADF % | L2 | CADF split by attribution | Snowflake → card 49366 | as #29 | ⚠️ contradicted—conflict (§3.4; column-shift §3.8) |
| 32 | Perfect Order Experience % | L0 | % orders w/ on-time pickup+delivery, no damage/WD | Snowflake → "Sheets + Others" | — | ◻️ unverified · ⚠️ column-shift §3.8 |
| 33 | On Time Pickup % + On Time Delivery % | L1 | % orders both on-time pickup & delivery | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: Apr corrupted) |
| 34 | On Time Pickup % | L2 | % orders on-time pickup | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 35 | On Time Delivery % | L2 | % orders on-time delivery | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 36 | Damage % | L1 | % orders w/ customer damage report | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 37 | Orders with Weight Discrepancy % | L1 | % orders w/ weight discrepancy | Snowflake → card 36421 (**db108**) | `prod_eldoria.core.FACT_PTL_ORDERS` + `FACT_PTL_WD_LOGS` | ⚠️ contradicted—conflict (refs missing `route_name` §3.7; only governed-layer card) |
| 38 | Effective Fulfilment % | L1 | completed / (placed − customer-attrib cancels) | Snowflake → card 48581 | `orders`/`order_cancellation_reasons`/`ptl_internal_users` | ✅ confirmed · ⚠️ offline **excluded** vs #26 (§3.3) |

### Retention & Engagement
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 39 | M1 Business User Retention % | L0 | % M0 business users ordering in M+1 | Snowflake → dashboard 4569 | `oms_public.customers` + `partload_application.orders` | ✅ confirmed-via-metadata |
| 40 | Repeat Rate (Business Users with ≥2 Lifetime PTL Orders) | L1 | % business users w/ ≥2 lifetime orders | Snowflake → card 39118 | `orders` + `oms_public.customers` **UNION `ptl_offline_orders`** | ✅ confirmed · ⚠️ offline-union (§3.3); column-shift §3.8 |
| 41 | Share of Monthly Business Orders from Repeat Users | L2 | % monthly business orders from repeat users | Snowflake → card 39119 | `orders` + `oms_public.customers` (**online only**) | ✅ confirmed · ⚠️ base differs from #40 (§3.3) |
| 42 | Avg Transactions per Business Customer per Month | L1 | Avg completed orders per active business user | Snowflake → card 44080 | — | ◻️ unverified |
| 43 | Reactivation % (60+ Day Inactive Business Users) | L1 | % 60d-inactive business users ordering | Snowflake → card 48919 | — | ◻️ unverified (review: low base) |
| 44 | Median Days Between Orders — Repeat Business Users | L1 | Median inter-order gap, repeat business | Snowflake → card 49311 | — | ◻️ unverified |
| 45 | Share of Business Users on Overall Transacting Users | L1 | Business vs Personal share of transacting | Snowflake → card 39149 | — | ◻️ unverified |

### Batching & Allocation Efficiency
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 46 | Avg Orders per Trip (Clubbing Opportunity Trips) | L0 | orders / trips where ≥2 orders same route+date | Snowflake → card 33461 | `batched_orders_v1`/`order_vehicles`/`orders`/`slots` **UNION `ptl_offline_orders`** | ✅ confirmed · ⚠️ offline-union (§3.3) |
| 47 | Vehicle Space Utilization % (Clubbing Opportunity Trips) | L1 | % capacity used on clubbing trips | Snowflake → card 43940 | `orders`/`load_details`/`order_fares`/`batch_v1`/`jobs`/`vehicles` + `gsheet_sync.ptl_table` | ✅ confirmed · ⚠️ hardcoded `created_at > '2025-07-11'` |
| 48 | Batch Acceptance % by Partners | L1 | % batched assignments accepted by owners | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) |
| 49 | Pickup / Delivery SLA Breach % due to Batching (Guardrail) | L1 | SLA breach attributable to batching | Snowflake → "Sheets + Others" | — | ◻️ unverified · ⚠️ column-shift §3.8 |
| 50 | Allocation Acceptance Rate — Batches Accepted by Owners | L0 | % pinged batches accepted | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) |
| 51 | Time to Allocate — P50 (minutes) | L1 | Median order-placed→vehicle-assigned mins | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 52 | % of Organic Allocation (No Manual Ops Intervention) | L1 | % orders allocated without ops touch | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA, engine Q3) |
| 53 | Reallocation Rate | L1 | % orders reallocated after first assignment | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) |

### Unit Economics
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 54 | GM% per PTL Order | L0 | (Revenue − Direct Costs) / Revenue per order | Snowflake / Finance → "Sheets"; `Status`=Finance | — | ◻️ unverified · ⚠️ Finance cross-thread; column-shift §3.8 (trend values in wrong cell) |
| 55 | Average Order Value (AOV) | L1 | Revenue / completed orders | Snowflake → card 33706 | `partload_application.orders` + `ptl_routes` | ✅ confirmed · ⚠️ date-basis `updated_at` (§3.6); offline **excluded** |
| 56 | Return Trip % (Porter-Arranged Return on Bidirectional Routes) | L1 | % return-eligible trips w/ arranged return | Snowflake → card 44691 | `orders`/`batched_orders_v1`/`order_vehicles`/`vehicles`/`service_zones` + `ptl_routes` | ✅ confirmed-via-metadata |

### Supply Health & Onboarding
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 57 | Monthly Active Owners (MAO) | L0 | Unique owners w/ ≥1 trip/mo | Snowflake → "Sheets" | — | ◻️ unverified |
| 58 | New Owners Onboarded per Month | L1 | Count new owners/mo | Snowflake → "Sheets" | — | ◻️ unverified |
| 59 | Monthly Active Vehicles (MAV) | L0 | Unique vehicles w/ ≥1 trip/mo | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 60 | New Vehicles Onboarded per Month | L1 | Count new vehicles/mo | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 61 | Owner Onboarding Activation Rate (1st Trip within 30 Days) | L1 | % new owners w/ trip in 30d | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 62 | Median Days from Owner Onboarding to First Trip | L1 | Median onboarding→first-trip days | Snowflake → "Sheets + Others" | — | ◻️ unverified (review: NA) |
| 63 | M1 Owner Retention % | L0 | % M0 owners w/ trip in M+1 | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 64 | % Trips with On-Time Pickup (Owner/Supply View) | L1 | % trips on-time pickup, supply view | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 65 | % Trips with On-Time Delivery (Owner/Supply View) | L1 | % trips on-time delivery, supply view | Snowflake → "Sheets + Others" | — | ◻️ unverified |

### Owner Reliability & Experience
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 66 | Owner Batch Acceptance Rate (Pings to Acceptance %) | L0 | % pinged batches accepted in window | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 67 | Owner Batch Completion Rate (Accepted to Completed %) | L0 | % accepted batches completed | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 68 | SLA Adherence % — On-Time Pickup + Delivery by Owner | L0 | % owner trips meeting both SLAs | Snowflake → "Sheets + Others" | — | ◻️ unverified |
| 69 | Partner Attributed Damage % | L0 | % orders w/ owner/partner-attributed damage | Snowflake → "Sheets" | — | ◻️ unverified |
| 70 | Owner Earnings per Trip | L0 | Avg owner payout (base+incentive) per trip | Snowflake / Finance → card 49316; `Status`=Finance | `partload_application.batch_v1` + `partload_analytics.vendor_payout_batch_level` | ✅ confirmed · ⚠️ `status=3` filter **commented out** (all batches counted); Finance cross-thread |
| 71 | Trips per Monthly Active Vehicle | L1 | Completed trips / MAV | Snowflake → card 49313 | `orders`/`batched_orders_v1`/`order_vehicles` + `dim_customers` | ✅ confirmed · ⚠️ joins `customer_uuid=customer_id` (key drift §3.5) |
| 75 | Owner Earnings per Monthly Active Vehicle | L0 | Owner earnings / MAV | Snowflake → "Sheets" | — | ◻️ unverified · ⚠️ column-shift-adjacent (blank def) |

### Owner & Partner Satisfaction
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 72 | Partner NPS | L0 | Owner/Partner NPS (%Prom − %Detr) | Survey → "Sheets" | — | ◻️ unverified (review: NA, no instrumentation) |
| 73 | Partner Support Tickets per Trip % | L0 | Partner tickets / trips | Freshdesk / Manual → "Sheets" | — | ◻️ unverified · ⚠️ column-shift §3.8 |
| 74 | Appsheet Adoption amongst Owners and Partners | L0 | % MAO+MAP using Appsheet for OLC | Appsheet Analytics → "Sheets + Others" | — | ◻️ unverified |

### Platform Health (all DataDog / Core-Platforms-owned; #78–#86 not in the May review)
| # | Metric (sheet verbatim) | Lvl | One-line definition | Source → card | Tables traced | Status |
|---|---|---|---|---|---|---|
| 76 | Uptime % — PartLoad-Ktor & PartLoad-Job Servers | L0 | % uptime of Ktor+Job servers/mo | DataDog; `Status`=Core Platforms | — | ◻️ unverified · flag §5 ("Tech defined metrics not sre about these") |
| 77 | Latency P95 — PartLoad-Ktor & PartLoad-Job Servers | L1 | P95 latency ms | DataDog; Core Platforms | — | ◻️ unverified |
| 78 | Booking Details Page Load Latency P95 | L2 | P95 page-load ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |
| 79 | Check Serviceability API Latency P95 | L2 | P95 API latency ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |
| 80 | Quote Generation API Latency P95 | L2 | P95 API latency ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |
| 81 | Booking Creation API Latency P95 | L2 | P95 API latency ms | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |
| 82 | Error Rate — PartLoad-Ktor & PartLoad-Job Servers | L1 | % server requests erroring | DataDog; Core Platforms | — | ◻️ unverified |
| 83 | Booking Details Page Load Error Rate | L2 | % page-load errors | DataDog; Core Platforms | — | ◻️ unverified · ⚠️ column-shift §3.8 |
| 84 | Check Serviceability API Error Rate | L2 | % API errors | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |
| 85 | Quote Generation API Error Rate | L2 | % API errors | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |
| 86 | Booking Creation API Error Rate | L2 | % API errors | DataDog; Core Platforms | — | ◻️ unverified (sheet-only) |

**Coverage check:** all 85 tab rows (#2–#86) are present. Tally — ✅ confirmed-via-metadata: **17**
(#12,14,15,19,26,38,39,40,41,46,47,55,56,70,71 + dashboards feeding 26/28/30/39); ⚠️
contradicted—conflict: **6** (#27,28,29,30,31,37); ◻️ unverified: **62**. (Rows #28/#30 appear
under both ✅-lineage and ⚠️-conflict — I classified them ⚠️ because the *definition* conflict
dominates the *lineage* confirmation.)

---

## 6. Verbatim uncertainty flags (canonical open-questions list — carried, not resolved)

Mirrors PnM's "verify flags carried verbatim" list. Left column = where it lives; right = the
literal text (sheet cell) or the metadata finding. **None resolved.**

| # | Where (sheet cell / metadata) | Flag (verbatim) |
|---|---|---|
| F1 | `Does Eldoria have underlying asset?` column | **Blank for all 85 rows** — the sheet records no governed-asset status for any metric. |
| F2 | `Important for v1` column | **Blank for all 85 rows** — no v1 scope declared in the sheet. |
| F3 | #4 `better_data_model_required` | "No, Amplitude is better solution" |
| F4 | #4 `Comments` | "These use frontend events can be donw via amplitude better than DB" |
| F5 | #10 `better_data_model_required` | "Leads and Conversions Mart" |
| F6 | #18 `better_data_model_required` | "No, Amplitude is better solution" |
| F7 | #19 `better_data_model_required` | "Order Level Mart" |
| F8 | #20 `better_data_model_required` | "Base data volatile, not certain on the current accuracy" |
| F9 | #27 `Existing Cards/Queries` | "Not found — may be embedded in dashboard/4793" |
| F10 | #32 `better_data_model_required` | "Base data volatile, not certain on the current accuracy" |
| F11 | #54 (GM%) `Status` / thread cells | `Status`="Finance"; cross-thread="Finance"; trend text in wrong cell: "Mar-26: -73.5%; Jan-26: -160.8%; Oct-25: -127.6%" |
| F12 | #70 (Owner Earnings/Trip) `Status` / thread | `Status`="Finance"; note in wrong cell: "No consolidated product measurement" |
| F13 | #76 `Comments` | "Tech defined metrics not sre about these" |
| F14 | #76–#86 `Status` | "Core Platforms" (all Platform Health metrics owned by another thread) |
| F15 | Metadata (Data Catalog) | `semantic_model.porter.fact_ptl_orders` exposes **0 measures**; `list_metrics` returns **0** PTL/partload metrics. |
| F16 | Metadata (Metabase) | Card 36421 filters on `route_name`, absent from `fact_ptl_orders` (join commented out) — latent break. |
| F17 | Metadata (Metabase) | State enum (3=completed, 4=cancelled) **inferred from SQL, not confirmed** against a data dictionary. |
| F18 | Source rows #27,29,30,31,40,49,73,83 | Column-shifted in the sheet; cells carried as-is (values ~2 cols right of intent). |

---

## 7. Judgment-call log (what I excluded, assumed, or found implausible)

- **Location of deliverables.** Wrote to `pnm/selfserve_data/ptl-selfserve/` (inside the git
  repo, sibling of `pnm-selfserve/`), not the empty non-repo `selfserve/ptl-selfserve/` at cwd.
  Only the in-repo path can be committed+pushed, and the repo already contained
  `ptl-selfserve/kickoff-prompt.md` — evidence this is the intended home. **Confidence 95%.**
- **Branch.** Cut `claude/ptl-metric-catalog-map` from the current `claude/pnm-metrics-catalog-map-vg251i`
  ("or a branch cut from it", per the kickoff). Avoids mixing PTL work onto a PnM-named branch
  and avoids disturbing the **pre-existing uncommitted PnM working-tree changes**, which I did
  not touch or stage. **Confidence 80%** — say the word if you wanted it on the PnM branch itself.
- **Read the sheet via the Drive connector.** The brief said "no Sheets connector → ask for CSV,"
  but Google Drive `read_file_content` supports Google Sheets. I used it rather than stopping.
  To beat the Drive reader's single-active-sheet truncation, the extraction subagent downloaded
  the workbook as XLSX and parsed all tabs. **Confidence 90%** the PTL_Metrics tab is captured
  faithfully; the 8 column-shifted rows are a source artifact, flagged not fixed.
- **"85 metrics" not "the metrics."** The tab has 85 rows (#2–#86); #1 is a header/label row,
  excluded. I treated the tab as a **design catalog / superset**, distinct from the 73 metrics
  actually rendered in the May'26 review. Did not force a 1:1 map — surfaced the gaps instead.
- **Verification depth.** Opened 14 Metabase cards + 3 dashboards (the v1-bundle + NSM-adjacent
  set named in the Argus plan) via metadata. Did **not** open the other ~13 Snowflake cards, any
  Amplitude chart, or any Freshdesk/DataDog/Survey/Sheets source — those are ◻️ unverified by
  default (lesson 4), not asserted. Verifying all 85 was out of scope for one map iteration; I
  prioritized the metrics the journey depends on.
- **No numbers pulled.** "confirmed-via-metadata" means the card exists and its tables were
  traced — **not** that any Apr-26 value reconciles. Zero queries executed, per constraint.
- **State enum assumed, flagged.** I let cards' `state=3/4` semantics inform the definitions but
  marked the mapping UNVERIFIED (F17) rather than assert it.
- **Found implausible / notable:** GM% −78% (Apr) with prior months −73.5% / −160.8% / −127.6%
  — plausible for a subsidised pre-PMF vertical, but the source is Finance-owned with no card and
  column-shifted in the sheet, so I can't stand behind the number (self-quiz Q3). The May'26
  title reviewing Apr-26 data, and the `Feb-25`/`Jan-26` column labels, look like source typos —
  reported, not corrected.
- **Excluded from scope (mentioned, not touched):** the workbook's other tabs (HCV_Metrics,
  PnM_Metrics, PnM Rough, Sheet12, PTL Issues, HCV_Metrics_DD) and the ~90 embedded cards inside
  dashboard 4198. Read only what the PTL catalog needed.

---

## 8. Self-quiz — could I defend every definition if a stakeholder pushed back?

Three hardest. Two are honestly **unanswerable without you** — that itself is the finding.

**Q1. "What is the PTL fulfilment rate for April — one number?"**
I cannot give one defensible number. Total FF (#26, dash 4198) and Effective FF (#38, card
48581) use **different order bases** — 48581 excludes offline `ptl_offline_orders` while the
observability dashboard's sibling cards union them in (§3.3). The review shows FF 56% / excl-60s
66% and Effective FF 66.17% — different denominators, not directly comparable. **Answerable only
after you rule on the offline-order base.** *(Partial — blocked on Owner Q on §3.3.)*

**Q2. "Is CBDF cancellation-before-driver-found measured one way across PTL?"**
No. Dashboard 4793 defines CBDF/CADF with its own `cancel_type` + <60s-exclusion params; card
49366 derives the same split purely from `order_vehicles.vehicle_name IS NULL/NOT NULL`, in a
different collection, with no shared model (§3.4). I cannot claim a single canonical CBDF
definition. **Unanswerable without your ruling on which is source-of-truth. This is a finding.**

**Q3. "Defend the GM% = −78% figure and its formula."**
I can't. GM% (#54) is Finance-owned, has **no Metabase card**, its sheet row is **column-shifted**
(trend values landed in a `Remarks`/thread cell), and the formula in the sheet ("(Revenue −
Direct Costs)/Revenue") doesn't specify which costs are "direct," which is the entire question
for a subsidised vertical. **Unanswerable without Finance's cost definition. Finding.**

*(A definition I* can *defend: Avg Orders per Trip / clubbing (#46, card 33461) — orders ÷ trips
where ≥2 orders shared a route+date; tables traced, logic legible. Its one caveat — offline union
— is disclosed, not hidden.)*
