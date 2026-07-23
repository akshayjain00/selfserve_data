# PTL Self-Serve — Decision Log

*Living record of every consequential decision, its rationale, evidence, and status.
Track A of iteration 2 ("definitions locked"). Owner rulings captured 2026-07-23.
Owner: akshay.jain@theporter.in · Repo: `akshayjain00/selfserve_data` @ `claude/ptl-metric-catalog-map`*

> These rulings resolve the open questions from `iteration-1-ptl-journey-proposal.md` §A.
> Confidence % = the owner's/analyst's stated confidence at decision time, carried for auditability.
> Nothing here is READY FOR STAKEHOLDERS; readiness stays owner-promoted.

---

## 1. Decisions (owner rulings, 2026-07-23)

### D1 — Consumption model: generate the monthly review doc FIRST  *(was Q0)*
- **Status:** ACTIVE · **Confidence:** 70%
- Product output #1 is an **auto-generated monthly PTL review** from the registry — removes the manual monthly rewrite (the real pain) and is the strongest leadership demo. Ad-hoc NL Q&A comes later on the same engine.
- **Consequence:** the deterministic engine is the substrate; the first thing built on top is a doc/trend generator, not a query CLI.

### D2 — Source path: raw `partload_application` now, governed later  *(was Q1)*
- **Status:** ACTIVE · **Confidence:** 75%
- Build on raw `PROD_CURATED.partload_application` where the numbers actually live; use governed `PROD_ELDORIA.core.fact_ptl_orders` for orders where it already suffices; migrate fully when CATEGORY_ANALYTICS adds measures + cancellation/allocation models.
- **Evidence:** governed fact exists but has 0 measures and is bypassed by 13/14 cards (catalog §2–3).
- **Consequence:** prototype is bug-for-bug with the chosen dashboards on raw tables; quirks disclosed in the answer footer. Do **not** block delivery on another team's roadmap.

### D3 — Offline-order base: NOT locked yet — prototype must SHOW BOTH  *(was Q2)*
- **Status:** OPEN BY DESIGN (conflict-exposure) · owner rules after seeing the gap
- Every ratio (FF, effective FF, AOV, conversion, avg-orders/trip) must be emitted **with AND without** `prod_curated.gsheet_sync.ptl_offline_orders`, side-by-side, until the owner picks the canonical base.
- **Why:** cards disagree today (catalog §3.3); the offline gap size should inform the ruling, not a guess.
- **Consequence:** this is the Track-B "expose, don't silently pick" requirement made concrete.

### D4 — North Star = "Monthly Transacting Business Customers on PTL"  *(was Q3)*
- **Status:** ACTIVE · **Confidence:** 80%
- Matches the live May'26 review + the sheet (Apr-26 = 2247). Supersedes the older Project-Argus "30-day repeat rate" framing (treated as stale).
- **Consequence:** NSM anchors the registry top and the generated review. Repeat-rate / retention metrics remain as supporting L1s.

### D5 — Canonical cancellation definition = Dashboard 4793  *(was Q4)*
- **Status:** ACTIVE (pending reconciliation check) · **Confidence:** 65%
- CBDF/CADF follow the "PTL Cancellations" dashboard 4793 (carries the <60s-cancellation exclusion the review reports).
- **Gate:** before CBDF/CADF ship, confirm standalone card 49366's simpler logic (`order_vehicles.vehicle_name IS NULL/NOT NULL`) **reconciles** to 4793 (owner-run). If it diverges materially, revisit.

### D6 — v1 bundle = 11 card-verified Snowflake metrics  *(was Q5)*
- **Status:** ACTIVE · **Confidence:** 70%
- In v1: **NSM (Monthly Transacting Business Customers), Completed Orders (business), Total Fulfilment %, Effective Fulfilment %, CBDF %, CADF %, Avg Orders per Trip (clubbing), AOV, Business Session Conversion, New Business Users, M1 Business Retention.**
- **Deferred:** Time-to-Allocate P50 → iteration 2.5 (source is a manual sheet, no verified card — would drag v1 trust down).
- **Consequence:** all 11 are in the review ∩ Snowflake-sourced ∩ card-verified (catalog §5).

### D7 — Architecture: shared CORE ENGINE only; per-vertical registries; forward-migrate  *(shared-engine question)*
- **Status:** ACTIVE · **Confidence:** 75%
- Extract the mechanical/safety layer into a shared `core/` both verticals import: read-only SQL guard (regex + sqlglot AST), dry-run CLI scaffolding, answer/trust footer, resolver + refusal mechanics, test-harness utilities, and the registry **schema**. **Metric catalogs stay per-vertical** (separate namespaces).
- **Forward-migration:** PTL builds on the freshly-extracted core; PnM migrates later when convenient — **no big-bang refactor of validated PnM work now**.
- **Not now:** a shared cross-vertical metric namespace — it hits the unsolved B-002 name-collision (PnM/HCV/PTL all have "allocation"/"fulfilment"/"CBDF") and needs a domain-disambiguation layer first.

---

## 2. Pre-work (before any Track-B number is trusted)

- **P1 — Confirm the `orders.state` enum** (assumed 3 = completed, 4 = cancelled). Cheapest, highest-leverage check: if wrong, every fulfilment & cancellation number is wrong. Confirm via data dictionary / catalog metadata or owner knowledge — **not** a production query. (catalog flag F17)
- **P2 — Confirm Metabase db108 vs db73** resolve to the same Snowflake account/role before treating the one governed-layer card (36421) as comparable to the rest (catalog §3.2).

## 3. Open reconciliation items (settle during v1 build / owner-run execution)

| Item | From | Action |
|---|---|---|
| Offline-order base ruling | D3 | Owner picks canonical base after seeing both in the prototype. |
| 4793 ↔ 49366 cancellation reconciliation | D5 | Owner-run compare before CBDF/CADF promote. |
| Customer Business/Personal source + join-key drift | catalog §3.5 | Pick one source (`oms_public.customers` vs `dim_customers`) + one key. |
| AOV date-basis | catalog §3.6 | Pick `created_at` (consistent with funnel) vs `updated_at`. |
| Card 36421 `route_name` break | catalog §3.7 | Route around; never use the route filter on the governed card until the model adds the column. |

## 4. Constraints reaffirmed (carry forward)

Dry-run default; **no production query without showing exact SQL + explicit owner go-ahead**; ratios computed from raw counts (never averaged); MTD-vs-locked-month labeled; section readiness owner-promoted only; nothing opened to stakeholders; AI never authors SQL.

---

## 5. Next: Track B (read-only prototype) — scope, not yet built

Per D1/D2/D6: a dry-run engine over the 11-metric v1 bundle on raw `partload_application`, emitting the offline/online both-bases view (D3), on the shared core (D7). No production data touched without a go-ahead. Awaiting owner "go" to begin (it is code — a step change from map).
