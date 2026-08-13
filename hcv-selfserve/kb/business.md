# business.md — what HCV is, its vocabulary, and its conventions

`B-###` rows. Schema and rules: [CONTRIBUTING.md](./CONTRIBUTING.md). Entry point: [CONTEXT.md](./CONTEXT.md).
All rows `last_verified: 2026-08-14`.

> **Why so much of this file reads `verified` while its *strategic* content is missing.**
> The confidence scale grades **evidence type**, not importance ([CONTRIBUTING.md](./CONTRIBUTING.md) §4).
> Almost everything below was read out of SQL, card metadata or the dbt catalog, so it is `verified`
> — but that is exactly why the file is strong on *mechanics* and near-empty on *posture*. Nobody
> writes "HCV is pre-PMF" into a `WHERE` clause. **The business framing is a gap (`G-020`), not an
> oversight**, and this file must not be read as a strategy document.

---

## §1 What HCV is

| id | statement | source_ref | confidence | note |
|---|---|---|---|---|
| **B-001** | **HCV = Heavy Commercial Vehicle** — Porter's trucking vertical, distinct from PnM (Packers & Movers), PTL (Part Truck Load) and the 2W/3W fleets. | `store:metric.porter.*` tag `domain:HCV`; Data Catalog `model.porter.hcv_overall_demand_mart` tags `domain:HCV` | **verified** | — |
| **B-002** | HCV's vehicle scope is **`9ft, 10ft, 14ft, 17ft, 19ft`** (`T-021`). Some cards reach the same intent via `level0_mapping = 'HCV'`. | `repo@20f6416:hcv-selfserve/hcv_metrics_queries.md#L37`; `metabase:card/32713` | **verified** | Card picklists sometimes offer `8ft`, outside this scope → `T-021a` |
| **B-003** | Reporting is scoped to **Tier 1** geographies (`T-022`). | `repo@20f6416:…#L39` | **verified** | Tier is not a governed dimension → `T-022a`, `T-022b` |
| **B-004** | HCV demand arrives through **four booking types** — Schedule Order, Express Order, SPOT on Tray Order, SPOT Order (`T-027`). | `metabase:card/55561` | **verified** | Only source in this KB that defines them |
| **B-005** | **SOT ("Spot on Tray")** is HCV's marketplace: orders are listed on a tray and partners accept from it, rather than being force-assigned. Marked by `so_driver_assignment_type = 4`. | `metabase:card/55561` (`T-027b`); `gsheet:HCV_Metrics_DD` domain `Allocation-SOT` | **verified** | — |
| **B-006** | The demand side is modelled as a **full outer join of Scheduled Orders (SO) and Fact Orders (FO)** — a row may exist on either leg or both (`T-050`, `T-050a`). | Data Catalog `model.porter.hcv_overall_demand_mart` | **verified** | This is why allocation keys off `fo_driver_id`, not `driver_id` |
| **B-007** | The Sheet organises HCV's target-state metrics into **four domains**: Allocation-SOT · Onboarding · Partner Lifecycle · OLC-Partner. | `gsheet:HCV_Metrics_DD` | `assumption` | Ladder rung 5 — AI-drafted, every row `Status = Pending` |
| **B-008** | ⚠️ **HCV's business posture — stage, unit economics, margin, strategic priority — is not established anywhere in this KB's sources.** | — | — | Deliberately empty. → `G-020` |

---

## §2 Interventions and GTM events

Dated events that explain a step-change in a trend. **This section is empty**, and that is a
finding, not an omission — none of this KB's sources record pricing changes, city launches,
campaigns or policy changes for HCV.

> ⚠️ Without this section, **no trend movement in HCV can be attributed.** A drop in fulfilment
> could be supply, seasonality, a pricing change, or a city launch, and nothing here distinguishes
> them. → `G-021`

---

## §3 Porter metric conventions — treat as non-negotiable

Cited directly by [CONTEXT.md](./CONTEXT.md)'s hard rules.

| id | statement | source_ref | confidence |
|---|---|---|---|
| **B-030** | **Aggregate-then-ratio.** Aggregate numerator and denominator at the cut you need, *then* divide. Never average daily ratios. | Porter house rule, carried from PnM/PTL; the pack computes every ratio this way (`repo@20f6416:…#L522–L524`) | **verified** |
| **B-031** | **Never average percentiles.** A weekly p50 is not the mean of daily p50s. | `nb1882` and `nb4146` design callouts, both naming it the largest roll-up trap | **verified** |
| **B-032** | **Divide-by-zero → null**, never zero. The pack uses `NULLIF(x, 0)` and `div0()`. | `repo@20f6416:…#L122,L522` | **verified** |
| **B-033** | Percentage movements are expressed in **"pp"** (percentage points), not "%". | Porter house rule, carried from PnM/PTL | **verified** |
| **B-034** | **Non-additive counts are never summed across periods** — any `COUNT(DISTINCT …)` over customers, partners or sessions. | `nb4146` design callout: *"summing daily DAP to a weekly number double-counts partners"* | **verified** |
| **B-035** | **A category dimension may contain overlapping members** (`T-024`). Summing across it is not safe by default in HCV. | `repo@20f6416:…#L496–L507` | **verified** |

---

## §4 Glossary

| id | term | expansion | source_ref | confidence |
|---|---|---|---|---|
| B-040 | **FF** | Fulfilment % — completed ÷ placed | `pack:§2` | **verified** |
| B-041 | **E-FF** | Effective Fulfilment % — completed ÷ (placed − customer-attributed cancellations) | `pack:§2`, `T-058` | **verified** |
| B-042 | **Unique FF** | Completed ÷ *deduplicated* demand (`B-062`) | `pack:§3` | **verified** |
| B-043 | **CBDF** | Cancelled Before Driver Found | `nb1882:M012`, `store:metric.porter.cadf` family | **verified** |
| B-044 | **CADF** | Cancelled After Driver Found | `nb1882:M013`, `store:metric.porter.cadf` | **verified** |
| B-045 | **CAC · PAC · PoAC** | Customer · Partner · Porter After-allocation Cancellation — the three CADF attributions | `gsheet:HCV_Metrics_DD`; `metabase:card/55612` | **verified** |
| B-046 | **MO** | Missed Order — no allocation within the window | `metabase:card/55612` description; `gsheet:HCV_Metrics_DD` | **verified** |
| B-047 | ⚠️ **SO** | **Overloaded — two unrelated meanings.** (a) **Schedule Order** / Scheduled Orders leg (`T-027`, `B-006`); (b) **Stock Out** — demand failing for zero supply (`metabase:card/55612`: *"MO, SO, CADF, PAC, CAC and PoAC"*) | `metabase:card/55561` vs `metabase:card/55612` | **verified** |
| B-048 | **ATA** | Actual Time of Arrival at pickup | `nb1882:M046`, `metabase:card/55503` | **verified** |
| B-049 | **ETA** | Estimated Time of Arrival | `nb1882:M045`, `metabase:card/55610` | **verified** |
| B-050 | **DAP · MAP** | Daily · Monthly Active Partners. **The two are defined on different bases** — see `B-071` | `store:metric.porter.map`; `pack:§5` | **verified** |
| B-051 | **Dry run** | Unbilled travel from the partner's location to the customer pickup point | `gsheet:HCV_Metrics_DD`; `nb1882:M044` | **verified** |
| B-052 | **NCR** | National Capital Region — in HCV metrics, exactly `geo_region_id = 2` (`T-023`) | `repo@20f6416:…#L381` | **verified** |
| B-053 | **FO · SO legs** | Fact Orders · Scheduled Orders — the two sides of the demand mart (`B-006`) | Data Catalog `model.porter.hcv_overall_demand_mart` | **verified** |
| B-054 | **Doshi categories** | Health · Usage · Adoption · Satisfaction · Ecosystem · Outcome — the classification both inventories use | `nb1882`, `nb4146` field glossaries | **verified** |
| B-055 | **L0–L3** | Metric levels: L0/NSM headline down to L3 diagnostic | `nb1882`, `nb4146` field glossaries | **verified** |
| B-056 | **Argus** | Porter's cross-vertical Metric Store programme — surfaces as `metric.porter.*` (`§5`) | `gsheet:HCV_Metrics_DD` column *"Implementation Phase for Project Argus"* | **verified** |
| B-057 | **MBG** | Minimum Business Guarantee — a gap-fill top-up to a partner earnings floor, not an additive bonus | `store:metric.porter.mbg_incentive_manually_adj` | **verified** |
| B-058 | **TPO** | Tickets Per Order | `gsheet:HCV_Metrics_DD` | **verified** |

> ⚠️ **`B-047` is a live ambiguity, not a curiosity.** "SO" appears in card *titles and descriptions*
> meaning **Stock Out**, and in *column names and SQL* meaning **Scheduled Order**. Read the SQL, not
> the label. → `G-022`

---

## §5 House formulas and standard dimensional cuts

| id | statement | source_ref | confidence |
|---|---|---|---|
| **B-060** | **The standard HCV scope filter** is: `vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')` **and** Tier 1 **and** `customer_mobile <> '0000000001'` **and** `COALESCE(order_status,5) IN (4,5)`. A figure missing any one of these is not comparable to a reported HCV number. | `repo@20f6416:…#L36–L40` (`T-020`, `T-021`, `T-022`, `T-002`) | **verified** |
| **B-061** | **The standard cut is `month × category × distance`.** Category per `T-024`/`T-024a`; distance per `T-025`. | `pack:§2`, `§3`, `§4`, `§6` | **verified** |
| **B-062** | **Duplicate demand** (excluded from unique demand) = same customer, pickup **and** drop within **100 m**, next order within **60 min**, and the earlier order cancelled (`order_status = 5`). | `repo@20f6416:…#L473–L484` | **verified** |
| **B-063** | **Allocation is detected by `fo_driver_id IS NOT NULL`** — explicitly *not* `driver_id`. | `repo@20f6416:…#L512`; pack scope note *"Allocation uses `fo_driver_id` … not `driver_id`"* | **verified** |
| **B-064** | Reporting granularity is **monthly**; a partial month must be labelled month-to-date. | `pack` scope block: *"Period: May–Jul 2026, reported monthly (Jul is a partial month)"* | **verified** |

---

## §6 Governance — what the metric store requires

`D-013` makes this KB a **migration map** toward `metric.porter.*`. These rows record what the
target actually demands.

| id | statement | source_ref | confidence |
|---|---|---|---|
| **B-070** | **Every store metric carries named ownership and an approval record** — `business_owner`, `technical_owner`, `approved_by`, `approval_date`, and a governance `version`. Example: `metric.porter.map` — business owner `ankush.lohani@theporter.in`, approved by `sandip.dogra@theporter.in` on 2026-06-24, version 1.0. | `store:metric.porter.map` `metricMetadata.meta` | **verified** |
| **B-070a** | This gives every migration gap a **real `next_action` target**. Where a store counterpart exists, its owner is the person the gap is blocked on — no separate ownership exercise is needed. | derived from `B-070` | **verified** |
| **B-071** | ⚠️ **The store defines MAP as order-based** — `COUNT(DISTINCT driver_id) WHERE total_completed_orders >= 1`, monthly. The pack defines it as **login-based** — a partner-day with `SUM(business_login_hours) > 0.5`. | `store:metric.porter.map` `calculation_logic`; `repo@20f6416:…#L439` | **verified** |
| **B-072** | Store metrics carry a **freshness contract** — `metric.porter.map` is `data_latency: T+1`, `refresh_cadence: daily`. | `store:metric.porter.map` `meta.freshness` | **verified** |
| **B-072a** | ⚠️ **The pack has no freshness contract at all** — its base table is a hand-run sandbox object (`T-073`). This is a concrete, statable gap between current state and the target. | `T-073` vs `B-072` | **verified** |
| **B-073** | Store metrics declare **relationships** — parent, child and related metrics. `map` is the root of the PLC active-base tree, with `payout_per_active`, `orders_per_active` and `login_hrs_per_active` as children. | `store:metric.porter.map` `meta.relationship` | **verified** |

> ⚠️ **`B-071` is the migration's first real cost.** Repointing MAP at the store **changes the
> number reported in the MBR**, because a partner who logs in but completes nothing counts in the
> pack and not in the store. It is a business decision, not a mechanical repoint. → `G-023`

---

## §7 Snapshot — reported values

**This section is deliberately empty.**

No number in this KB has been validated against the warehouse. No query has been run; the pack's
base table (`T-073`) has not been rebuilt in this engagement; and `T-030` leaves the **unit scaling
of every revenue and AOV figure unresolved**.

Per [CONTRIBUTING.md](./CONTRIBUTING.md) §7, values live **only** here, tagged by **data period**
(`May-2026`), never by review name. When the first snapshot is added it must carry:

- a blockquoted preamble — point-in-time, source, capture date, and that every value is `unverified`
- **current and prior period** columns, so movement is readable
- inline `⚠️` and gap IDs on any figure with an open caveat

→ `G-024`
