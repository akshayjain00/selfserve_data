# P2d Extract — PTL Product Ops Review (Notion)

Source: Notion page ID `3449c6eaaa6d8036bb51d679b6182767`, fetched read-only.
Fetch tool reported "as of 2026-05-21T06:33:56.879Z" — this is the fetch/render timestamp, not a confirmed last-edited timestamp (fetch payload exposed no `last_edited_time` property).

---

## Document metadata

- **Title (as stored in Notion):** "PTL Product Ops Review: May'26" (note: orchestrator brief gave the title as "PTL Product Ops Review, May '26" — punctuation differs slightly; the page's own `<properties>` block says `"title":"PTL Product Ops Review: May'26"`).
- **Stated period:** Title says "May'26", but every data table's latest/leftmost column is **Apr-26**, with six trailing monthly columns back to Oct-25. So this is the May-26 *review meeting* covering **Apr-26 as the latest completed month**, trended against Mar-26 → Oct-25.
- **Last-edited date:** not exposed by the fetch tool. Only a fetch-time timestamp (2026-05-21T06:33:56.879Z) is available.
- **Section outline (headings in order):**
  1. `## Product Context` — narrative bullets, no metrics table.
  2. `## Observability` — contains a callout defining the North Star Metric, then four collapsible (`toggle`) subsections, each a wide metrics table with identical column shape (Metric Category | Question | Metric | Insights/Observations | Apr-26 | Mar-26 | **Feb-25 [sic]** | Jan-26 | Dec-25 | Nov-25 | Oct-25 | Dashboard Link):
     - `### Demand`
     - `### Marketplace`
     - `### Supply`
     - `### Health` (this one has two extra columns: Theme, SLO)

Notion inline discussion/comment threads (`discussion://...`) are attached to many cells but were not fetched (out of scope — read-only page-content extraction only, no comment fetch performed).

---

## Metrics appearing in the review

All are presented as **NUMBER** (a monthly time series with 7 columns), unless marked otherwise. Definition = the "Metric" column text (I've kept the doc's own "L0/L1/L2" level prefixes). "Section link/anchor" = section path only; Notion's fetch format does not expose per-block heading anchors, only page-level URL + `discussion://` comment IDs.

### Observability → Demand
| Metric | Definition (as given) | N/P | Section link/anchor |
|---|---|---|---|
| NSM: Monthly transacting business customers on PTL | (North Star, defined in callout above the tables) | N | Observability > Demand > NSM |
| L0: PTL awareness amongst Porter Business MAU | dipstick survey, base = SME user w/ ≥1 completed order in any category but new to PTL (also reported for base: SME user with Trucks order ≥2) | N | Observability > Demand > Adoption |
| L1: VSS TOF where PTL is serviceable for business users | not further defined | N | " |
| L1: VSS sessions where PTL serviceable as % of overall OS sessions (>100km) on VSS (cities where PTL launched) | as stated | N | " |
| L1: % of PTL card taps in PTL serviceable sessions by business users | as stated | N | " |
| L1: % of OS sessions where PTL was selected / % of sessions where either PTL or FTL was selected by business users (>100km cut) | as stated | N | " |
| L1: Outstation search rate | % of business users searching Outstation / total Porter Business users who searched for any vehicle | N | " |
| L0: PTL activation rate | business users completing first PTL order within 7 days / new business users viewing PTL card | N | " |
| L1: VSS -> Quote Check conversion for new Business users | as stated | N | " |
| L1: Quote check -> Order placed conversion for new Business users | as stated | N | " |
| L1: # New PTL business users acquired | completed 1st order | N | " |
| L2: Average number of sessions before first PTL completed order for business users | as stated | N | " |
| L0: M1 business user retention | % of business users who complete ≥1 order in M+1 | N | Observability > Demand > Usage |
| L1: Share of business users on overall transacting users (Business vs Personal) | as stated | N | " |
| L1: Share of repeat users in transacting SME base | % of PTL transacted business users with ≥2 orders | N | " |
| L2: Share of monthly business orders from repeat business users | as stated | N | " |
| L1: Median time to book by business user | as stated | N | " |
| L1: Avg. Transaction per business customer per month | as stated | N | " |
| L1: Reactivation % | % of PTL transacted business customers inactive 60+ days who placed an order | N | " |
| L0: Customer NPS / Sean Ellis test (Business users) | gathered via post-order calls; Promoters=9-10, Neutral=7-8, Detractors=1-6, NPS=Promoters−Detractors; **approach changed mid-Apr** (earlier: weighted average of 1-5 ratings) | N | Observability > Demand > Satisfaction |
| L0: Support Tickets per Placed Order | as stated | N | " |
| L1: Support ticket % | % of orders generating a support ticket | N | " |
| L1: First Contact Resolution% | as stated | N | " |
| L1: Escalation% | % of support tickets that escalate to social media / founder | N | " |
| L0: Perfect Order experience % | % of orders with SLA adherence + no damage/weight discrepancy | N | " |
| L1: On time Pickup + On time Delivery | calculated only on orders with both pickup & drop timestamps | N | " |
| L2: On Time Pickup | calculated on all orders with a pickup timestamp (larger base) | N | " |
| L2: On time Delivery | calculated on all orders with a drop timestamp (larger base) | N | " |
| L1: Orders with weight discrepancy | as stated | N | " |
| L1: Damage% | as stated | N | " |
| L0: Business session conversion | as stated | N | Observability > Demand > Outcome |
| L1: Overall session conversion | as stated | N | " |
| L1: VSS -> Quote check conversion for business users | as stated | N | " |
| L1: Quote check -> Order placed conversion for business users | as stated | N | " |
| L0: # Completed orders from business users | as stated | N | " |
| L1: PTL order share out of OS orders (>100km) | as stated | N | " |

### Observability → Marketplace
| Metric | Definition | N/P | Anchor |
|---|---|---|---|
| L0: Total Fulfilment% | reported as two figures: "FF" and "FF (excl 60s)" [excludes cancellations within 60s of booking] | N | Observability > Marketplace > Ecosystem |
| L1: Effective fulfilment | as stated | N | " |
| L1: CBDF | reported as CBDF% and "Excl 60s" variant; acronym not expanded in doc | N | " |
| L2: Customer / Porter attributed CBDF | split by attribution | N | " |
| L1: CADF | acronym not expanded in doc | N | " |
| L2: Customer / Porter / Partner attributed CADF | split 3 ways (Cx/Px/Porter) | N | " |
| L0: Average Orders per Trip | Total orders fulfilled / Total trips taken (where clubbing opportunity exists, ≥2 orders same route same-day pickup) | N | " |
| L1: % of vehicle space utilised where clubbing opportunity exists | as stated | N | " |
| L0: Acceptance rate (% of batches accepted by Owners) | doc note: "No existing product" | N (all NA) | " |
| L1: Time to allocate (P50) | unit not stated in doc (presumably minutes) | N | " |
| L2: % of organic allocation | doc note: allocation currently operationally driven; batching engine targeted Q2 dev / Q3 release | N (all NA) | " |
| L1: Reallocation rate | same note as above | N (all NA) | " |
| L0: GM% per PTL order | gross margin % per order | N | Observability > Marketplace > Outcome |
| L1: Average Order Value | no currency symbol given in doc | N | " |
| L1: Return trip% | % of return trips where Porter arranged a return order, wherever return route exists | N | " |

### Observability → Supply
| Metric | Definition | N/P | Anchor |
|---|---|---|---|
| L0: New owners onboarded per month | doc note: supply currently operationally driven; product-led solutions targeted Q2 release | N | Observability > Supply > Adoption |
| L0: New vehicles onboarded per month | same note | N | " |
| L0: Owner Onboarding Activation Rate | % of new owners completing ≥1 trip within 30 days of onboarding | N | " |
| L1: Median days from onboarding to first trip | doc note: "No existing product" | N (all NA) | " |
| L0: Appsheet Adoption amongst Owners | as stated | N | " |
| L1: Appsheet adoption amongst Partners | as stated | N | " |
| L0: Monthly Active Owners | as stated | N | Observability > Supply > Usage |
| L1: Monthly Active Vehicles | as stated | N | " |
| L1: Trips per Monthly Active Vehicle | as stated | N | " |
| L0: M1 Owner retention | as stated | N | " |
| L0: Partner NPS | doc note: "No instrumentation available" | N (all NA) | Observability > Supply > Satisfaction |
| L0: Support tickets per trip % | doc note: "No app existing" | N (blank/no data) | " |
| L0: SLA adherence% | % of orders with pickup & delivery time adherence; note: "could be very low at trip level, hence starting at order level" | N | Observability > Supply > Ecosystem |
| L1: % Orders with On time pickup% | as stated | N | " |
| L1: % Orders with on time delivery% | as stated | N | " |
| L0: Partner attributed damage % | doc note: "Not tracked right now" | N | " |
| L0: Owner earnings per Monthly Active Vehicle | as stated | N | Observability > Supply > Outcome |
| L1: Earnings per Trip | as stated | N | " |

### Observability → Health
| Metric | Definition | N/P | Anchor |
|---|---|---|---|
| L0: Uptime for PartLoad-Ktor & PartLoad-Job Servers | SLO = 99.9% | N | Observability > Health |
| L1: PartLoad-Ktor error rate | SLO = ≤0.5% | N | " |
| L1: PartLoad-Ktor latency P95 | SLO column = "-" (none set) | N | " |
| L1: L4 tickets (via social media / mystery shopping) | doc note: "High touch OLC by Ops team in case of escalation"; "Instrumentation needs to be built" | N (all NA) | " |

Every L0 metric in the doc also carries a narrative **"Question"** framing it in plain business language (e.g., "Are we growing the base of business customers who choose PTL as their go-to intercity logistics option each month?" for the NSM). These questions are prose-only, attached 1:1 to an L0 row — not separate narrative sections.

---

## Reported numbers (SNAPSHOT — as-of labelled)

**This is a point-in-time snapshot from the May'26 review; not a living metric definition.** Column header exactly as written in doc includes an apparent typo: `Feb-25` sits chronologically between `Mar-26` and `Jan-26` in every table — almost certainly meant to read `Feb-26`. Transcribed verbatim below as `Feb-25[sic]`.

| Metric | Apr-26 | Mar-26 | Feb-25[sic] | Jan-26 | Dec-25 | Nov-25 | Oct-25 | Comparison stated |
|---|---|---|---|---|---|---|---|---|
| NSM: Monthly transacting business customers on PTL | 2247 | 1879 | 1386 | 1456 | 1445 | 1113 | 800 | "Business session conversion has increased while FF has stayed stable." |
| L0: PTL awareness amongst Porter Business MAU | 37% (base: SME, any-category order ≥1, new to PTL); 45% (base: SME, Trucks order ≥2) | - | - | - | - | - | 25% | none stated |
| L1: VSS TOF where PTL serviceable for business users | 94k | 96k | 80k | 72k | 62k | 59k | 54k | GTM since mid-Mar in 5 cities drove Mar uplift; Apr had 70% TG overlap vs Mar → no further uplift |
| L1: VSS sessions where PTL serviceable as % of OS sessions (>100km) on VSS | 60.72% | 65.85% | 69.5% | 68.64% | 68.6% | 68.05% | 66.13% | dip due to April outstation serviceability expansion |
| L1: % of PTL card taps in PTL serviceable sessions | 11.79% | 10.61% | 9.54% | 10.74% | 12.23% | 10.68% | 9.74% | +1.18pp; FTUX campaigns from 16-Mar; ~15% price cut Blr↔Hyd drove 22% of lift; Mumbai-Ahmedabad/Surat (11 Mar) drove 27% |
| L1: % OS sessions where PTL selected / (PTL or FTL selected) | 46.07% | 43.07% | 44.81% | 48.99% | 49.04% | 46.82% | 39.98% | +3.89pp; same 3 drivers as above (8.6% / 17%) |
| L1: Outstation search rate | 10.2% | 6.53% | 2.34% | 2.21% | 2.25% | 2.09% | 1.97% | "Investigation ongoing, no clear driver identified yet" |
| L0: PTL activation rate | 2.5% | 2.2% | 1.6% | 2% | 2.4% | 2.1% | 1.7% | +0.46pp (~17%) driven by FTUX campaigns |
| L1: VSS -> Quote Check conversion (new business users) | 6.99% | 6.25% | 5.35% | 6.29% | 7.43% | 7.56% | 7.41% | +0.74pp; ~10% price cut Blr↔Hyd (10% of lift), FTUX, Mumbai-Ahmedabad/Surat (22% of lift) |
| L1: Quote check -> Order placed conversion (new business users) | 23.77% | 22.22% | 21.78% | 22.4% | 23.56% | 20% | 15.87% | higher-weight order mix, lower prices |
| L1: # New PTL business users acquired | 1466 | 1265 | 908 | 1016 | 1100 | 929 | 707 | same FTUX driver |
| L2: Avg sessions before first PTL completed order | 3.97 | 3.77 | 3.56 | 3.21 | 3.01 | 2.62 | 2.32 | "Investigation ongoing" |
| L0: M1 business user retention | - | M1:15.4% | M1:14.7% | M1:13.1% / M3:14% | M1:16.6% / M3:12% | M1:20.4% / M3:11.9% | M1:17.1% / M3:13.9% | entry price cuts (Blr→Chn 20.5%, Blr-Hyd 14.7%, Pun-Nashik 18%) end-Mar/early-Apr |
| L1: Share of business users of overall transacting users | 46.08% | 44.84% | 42.23% | 42.07% | 41.06% | 39.69% | 40.55% | GTM since mid-Mar; Apr uptick from higher repeat share |
| L1: Share of repeat users in transacting SME base | 34.36% | 32.41% | 33.69% | 29.6% | 22.01% | 12.31% | 0 | reactivation campaigns since March |
| L2: Share of monthly business orders from repeat users | 73.04% | 71.95% | 72.49% | 71.92% | 69.47% | 64.8% | 55.7% | same reactivation driver |
| L1: Median time to book by business user | 1.25m | 1.33m | 1.35m | 1.37m | 1.35m | 1.47m | 1.45m | doc's stated insight text: "Repeat order share has increased from 69% in Mar to 71.28% in Apr" (looks mismatched — see Contradictions) |
| L1: Avg. Transaction per business customer per month | 1.49 | 1.5 | 1.44 | 1.41 | 1.46 | 1.37 | 1.3 | "Stable" |
| L1: Reactivation % | 5.06%* | 4.85% | 3.85% | 3.93% | 6.05% | 5.07% | 2.33% | *doc footnote: base number very low |
| L0: Customer NPS / Sean Ellis (Business) | 53.85 | 4.45 | 4.42 | 4.44 | 4.46 | - | - | scale break mid-Apr (methodology changed — see Contradictions); Apr: 1,033 call attempts, 299 connected (~29% connection rate) |
| L0: Support Tickets per Placed Order | 0.28 | 0.3 | 0.34 | 0.35 | 0.32 | 0.34 | 0.35 | mid-Mar ticket-creation rule change lowers volume from Apr |
| L1: Support ticket % | 18.4% | 21.06% | 21.16% | 22.3% | 21.5% | 23.4% | 22.3% | same rule-change driver |
| L1: First Contact Resolution% | 54.1% | 53.46% | 64.68% | 63.27% | 21.5% | 49.3% | 58.5% | "Stable" (see Contradictions re: Dec-25 outlier) |
| L1: Escalation% | 0% | 0.067% | 0% | 0% | 0.038% | 0.04% | 0% | none stated ("NA") |
| L0: Perfect Order experience % | 41.41% | 50.64% | 48.55% | 53.23% | 45.63% | 41.64% | 46.35% | "Sharp dip attributed to the dip in On time pickup" |
| L1: On time Pickup + On time Delivery | 45.88%* | 54.79% | 51.28% | 57.37% | 50.06% | 47.27% | 56.58% | *Apr data corrupted (doc footnote); dip attributed to SOP changes favoring batching over pickup speed |
| L2: On Time Pickup | 61.8%* | 66.77% | 77.55% | 71.24% | 69.19% | 72.29% | 77.15% | *Apr data corrupted; same SOP driver |
| L2: On time Delivery | 71.38%* | 69.2% | 62.53% | 71.47% | 64.73% | 59.97% | 69.94% | *Apr data corrupted; delivery TAT relaxed by 1hr on some routes in Apr for higher clubbing |
| L1: Orders with weight discrepancy | 3.9% | 3.5% | 3.5% | 3.2% | 4.6% | 7.5% | 14% | penalty mechanism introduced |
| L1: Damage% | 0.27% | 0.3% | 0.47% | 0.31% | 0.34% | 0.54% | 0.3% | "Stable" |
| L0: Business session conversion | 5.43% | 4.62% | 3.86% | 4.38% | 5.09% | 4.62% | 3.95% | +growth: 55% from new-user conversion, 45% from mix shift to repeat share |
| L1: Overall session conversion | 5.39% | 4.62% | 4.06% | 4.66% | 5.44% | 4.88% | 4.13% | "Similar reason as above" |
| L1: VSS -> Quote check conversion (business users) | 10.09% | 8.81% | 7.55% | 8.57% | 9.81% | 9.14% | 8.37% | +1.28pp; ~15% Blr↔Hyd price cut (12.5% of lift), Mumbai-Ahmedabad/Surat (15% of lift) |
| L1: Quote check -> Order placed conversion (business users) | 53.81% | 52.44% | 51.1% | 51.07% | 51.94% | 50.52% | 47.18% | higher-weight order share growth |
| L0: # Completed orders from business users | 3341 | 2824 | 1997 | 2060 | 2115 | 1525 | 1038 | "session conversion increased from 4.62% to 5.43%" |
| L1: PTL order share out of OS orders (>100km) | 50.6% | 46.71% | 42.82% | 46.74% | 48.96% | 43.55% | 34.27% | +3.89pp; distance-bucket & route drivers (see extract table below) |
| L0: Total Fulfilment% | FF 56% / excl-60s 66% | FF 57% / excl-60s 67% | FF 57% / excl-60s 67% | FF 56% / excl-60s 67% | FF 57% / excl-60s 68% | FF 48% / excl-60s 59% | FF 41% / excl-60s 50% | "Stable" |
| L1: Effective fulfilment | 66.17% | 67.09% | 66.73% | 64.79% | 64.56% | 55.19% | 47.01% | "Stable" |
| L1: CBDF | 30% (excl-60s 14.66%) | 30.5% (14.84%) | 32.14% (16.43%) | 31.59% (15.17%) | 33.1% (16.91%) | 45.66% (27.35%) | 55.73% (36.96%) | "Stable" |
| L2: Customer / Porter attributed CBDF | Cx 8.96% / Porter 16.4% | Cx 9.23% / Porter 16.74% | Cx 9.7% / Porter 17.44% | Cx 9.38% / Porter 17.81% | Cx 9.16% / Porter 18.76% | Cx 10.99% / Porter 28.29% | Cx 12.84% / Porter 35.79% | driven by reduction in "change of mind" reasons |
| L1: CADF | 13.81% | 12.99% | 11.11% | 12.2% | 9.94% | 6.37% | 3.65% | +1.2pp in April from higher partner delay (Ops pushing increased batching) |
| L2: Customer/Porter/Partner attributed CADF | Cx 6.11% / Px 1.2% / Porter 6.24% | Cx 6.56% / Px 1.17% / Porter 5.01% | Cx 5.24% / Px 1.08% / Porter 4.21% | Cx 3.86% / Px 1.17% / Porter 6.87% | Cx 2.6% / Px 0.83% / Porter 6.26% | Cx 2.12% / Px 0.28% / Porter 3.76% | Cx 0.77% / Px 0.09% / Porter 2.54% | driven by reduction in "Ops requested cancellation" & "want to reschedule" reasons |
| L0: Average Orders per Trip | 1.59 | 1.58 | 1.54 | 1.45 | 1.54 | 1.56 | 1.57 | ops problem: trucks sent before enough orders gathered (see extract below) |
| L1: % vehicle space utilised (clubbing opportunity) | 37.34% | 34.25% | 33.46% | 26.76% | 24.25% | 23.53% | 25.25% | avg order weight rose 309kg→350kg Mar→Apr |
| L0: Acceptance rate (batches accepted by Owners) | NA | NA | NA | NA | NA | NA | NA | "No existing product" |
| L1: Time to allocate (P50) | 21.67 | 19.95 | 21.03 | 24.18 | 31.21 | 47.63 | 64.4 | order-volume surge + clubbing drove West-zone delivery time increases |
| L2: % of organic allocation | NA (all) | | | | | | | batching engine targeted Q2 dev/Q3 release |
| L1: Reallocation rate | NA (all) | | | | | | | same |
| L0: GM% per PTL order | -78.28% | -73.50% | -74.55% | -119.80% | -160.79% | -132.98% | -127.57% | price cuts on 3 routes compressed margin; trip costs flat |
| L1: Average Order Value | 2920 | 2,834 | 2,971 | 2,660 | 2,110 | 2,111 | 2,086 | higher-weight order mix from lower prices |
| L1: Return trip% | 20% | 21% | 20% | 20% | 19% | 24% | 24% | return-vehicle visibility (end-Feb) → "1pp jump in Mar"; doc also says "slight dip Feb→Mar→Apr" (contradictory wording — see below) |
| L0: New owners onboarded per month | 2 | 11 | 24 | 4 | 26 | 36 | 39 | supply is operationally driven; product-led supply targeted Q2 |
| L0: New vehicles onboarded per month | 216 | 273 | 216 | 207 | 285 | 312 | 290 | same |
| L0: Owner Onboarding Activation Rate | 50% | 47.37% | 41.67% | 0% | 24% | 30.56% | 27.91% | same |
| L1: Median days onboarding to first trip | NA (all) | | | | | | | "No existing product" |
| L0: Appsheet Adoption amongst Owners | 40.31% | 43.76% | 50.42% | 38.57% | 34.99% | 24.5% | 30.27% | pushed in West in Feb → 17% there; rolled back in Mar (increased allocation time) → back to 4-5% |
| L1: Appsheet adoption amongst Partners | 15% | 17% | 26% | 16% | 16% | 17% | 19% | same driver |
| L0: Monthly Active Owners | 99 | 103 | 119 | 108 | 124 | 125 | 103 | supply operationally driven |
| L1: Monthly Active Vehicles | 739 | 676 | 542 | 575 | 554 | 487 | 388 | same |
| L1: Trips per Monthly Active Vehicle | 6.2 | 5.74 | 5.43 | 5.89 | 5.92 | 4.85 | 3.95 | same |
| L0: M1 Owner retention | - | 84.47% | 73.11% | 83.33% | 80.65% | 75.2% | 82.52% | same |
| L0: Partner NPS | NA (all) | | | | | | | "No instrumentation available" |
| L0: Support tickets per trip % | (blank, all months) | | | | | | | "No app existing" |
| L0: SLA adherence% | 50.6% | 61.37% | 54.68% | 63.65% | 61.07% | 57.88% | 59.64% | none stated |
| L1: % Orders with on-time pickup% | 67.03% | 72.29% | 76.74% | 72.84% | 77.64% | 74.53% | 72.82% | none stated |
| L1: % Orders with on-time delivery% | 75.55% | 73.21% | 67.82% | 74.21% | 74% | 69.98% | 73.71% | none stated |
| L0: Partner attributed damage % | (blank) | 0% | 0.07% | 0% | 0% | 0% | 0% | "Not tracked right now" |
| L0: Owner earnings per Monthly Active Vehicle | 63952 | 61643 | 58780 | 58138 | 58137 | 46224 | 24328 | rose because trips per MAV rose |
| L1: Earnings per Trip | 12579 | 11788 | 11795 | 10950 | 10665 | 10158 | 6442 | "Change in the " (sentence truncated in source doc) |
| L0: Uptime PartLoad-Ktor / PartLoad-Job (SLO 99.9%) | Ktor 99.96% / Job 99.98% | Ktor 99.96% / Job 99.93% | Ktor 99.93% / Job 99.77% | Ktor 99.96% / Job 99.96% | (blank labels, no values) | (blank) | (blank) | "NA" |
| L1: PartLoad-Ktor error rate (SLO ≤0.5%) | 0.0005% | 0.0008% | 0.001% | 0.001% | 0.0024% | 0.0023% | 0.0097% | "NA" |
| L1: PartLoad-Ktor latency P95 (SLO: none set) | 15.22ms | 15.32ms | 7.86ms | 4.55ms | 4.86ms | 4.11ms | 3.46ms | "Route config & rate card was made configurable in Feb end" |
| L1: L4 tickets (social media/mystery shopping) | NA (all) | | | | | | | "High touch OLC by Ops team in case of escalation"; instrumentation not yet built |

Additional sub-extracts embedded as prose/mini-tables inside "Insights" cells (kept verbatim, period labels as given):
- Quote check -> Order placed, weight-slab conversion (new business users), **Mar vs Apr**: 0-250: 64%→64%; 251-500: 57%→55%; 501-1000: 41%→44%; 1001-2000: 31%→37%; 2001-3000: 30%→29%.
- Same weight-slab table repeated for business users generally (Quote check -> Order placed, Outcome section), **Mar vs Apr**: 0-250: 64%→64%; 251-500: 57%→55%; 501-1000: 41%→44%; 1001-2000: 31%→37%; 2001-3000: 30%→29%.
- Distance-bucket PTL order share, **Mar vs Apr**: 101-300km: 37.10%→41.66%; 301-500km: 85.75%→88.46%; 501-800km: 95.83%→96.21%.
- Completed order growth by route, **Mar vs Apr**: Blr-Chn 333→351; Blr-Hyd 167→188; Chn-Blr 267→294; Hyd-Blr 83→135; Nashik-Pune 23→33; Pune-Nashik 61→63.
- AOV weight-slab conversion, **Mar vs Apr**: 0-250: 53%→53%; 251-500: 49%→49%; 501-1000: 37%→38%; 1001-2000: 30%→33%; 2001-3000: 25%→25%.
- Return trip% breakdown, **Apr/Mar/Feb**: April: Ret trip Uz 20.10%, %SDD 17.95%, %NDD 20.80%. March: 22.25%, 19.14%, 22.97%. Feb: 20.82%, 21.82%, 20.85%.

---

## Business context

- **What PTL is:** a "pre-PMF product" (doc's own words) — still operationally assisted across multiple parts of the journey, not yet self-serve end to end.
- **Customer side:** booking journey lives on the Porter customer app (self-serve today).
- **Batching/allocation:** analytics scripts generate recommendations, but final batching and allocation decisions are made by Ops manually — not yet product-automated.
- **Vendor/partner onboarding:** happens via a Google form run by the Ops team; no self-serve onboarding journey exists yet.
- **Partner-side order lifecycle:** runs on a third-party tool called **Appsheet**, not a dedicated Porter partner app. Doc notes on-time metric accuracy "will improve once the partner app is live," implying a dedicated partner app is planned but not yet shipped.
- **North Star Metric:** Monthly Transacting Business Customers on PTL.
- **Metric taxonomy/framework used throughout:** every metric is tagged with a Metric Category (NSM / Adoption / Usage / Satisfaction / Outcome / Ecosystem / Health) and a level (L0/L1/L2, L0 being closest to the north star / business question). This taxonomy is applied identically across three "wings" — **Demand** (customer-facing), **Marketplace** (two-sided matching/fulfilment/margin), **Supply** (owner/vehicle-facing) — plus a separate **Health** wing (platform reliability).
- **Every L0 metric is paired with a plain-English "Question"** framing the business intent (e.g., "Are we adding enough new owners to the PTL supply base each month to keep pace with demand growth?"). These are the clearest available statements of what Product Ops is actually trying to answer with each number.
- **Customer segmentation:** Business vs Personal customers (PTL is compared to Personal-category usage in one metric); within Business: new vs. repeat vs. reactivated (60+ days inactive). "SME" (small/medium enterprise) used as base description for the awareness dipstick survey.
- **Funnel/lifecycle stages tracked:** Awareness → VSS (session) → Quote check → Order placed → Order completed → Retention (M1/M3) → Reactivation.
- **GTM activity in the period:** FTUX (first-time-user-experience) campaigns launched mid-March in five cities — Mumbai, Pune, Bangalore, Hyderabad, Chennai — targeting new business users; continued into April but with 70% target-group overlap vs March, so no incremental uplift in April.
- **Pricing interventions cited:** ~15% price reduction on Bangalore↔Hyderabad (quote-check/session-conversion context); ~10% price reduction Bangalore↔Hyderabad (a different metric context, possibly the same cut described differently — see Contradictions); entry-price cuts end-March/early-April across three route clusters: Bangalore→Chennai −20.5%, Bangalore-Hyderabad −14.7%, Pune-Nashik −18%.
- **Serviceability/route expansions:** Outstation serviceability expanded in April (caused a dip in one VSS-serviceability metric); Mumbai-Ahmedabad and Mumbai-Surat routes enabled 11 March.
- **Engineering change:** route config & rate card made configurable at end of February.
- **AppSheet rollout history:** pushed to the West region in February (adoption rose to 17% there), but this increased allocation time, so it was rolled back in March (adoption fell back to 4–5%). Current overall Owner AppSheet adoption ~40%, Partner adoption ~15–17%.
- **Batching engine / product-led supply:** both explicitly "currently operationally driven" today; batching engine picked for development in Q2, targeted for Q3 release; product-led supply solutions also targeted for Q2 release.
- **Unit economics:** GM% per PTL order is deeply negative every single month shown (range roughly −73% to −161%), i.e., Porter is heavily subsidizing PTL growth; April saw margin compression again due to the three route price cuts while trip costs stayed flat.
- **"Excl 60s" filter:** fulfilment/cancellation metrics are reported both including and excluding cancellations made within 60 seconds of booking (a data-quality/accidental-booking filter).
- **NPS methodology change:** mid-April the Business-user NPS calculation switched from a weighted average of 1–5 star ratings to a standard Promoter–Detractor NPS (9–10 = promoter, 7–8 = neutral, 1–6 = detractor). Only 1,033 call attempts were made in April, with 299 successfully connected (~29% connection rate); NPS is gathered via post-order calls done by the CGE team.
- **Support ticket definition change:** starting mid-March, tickets are no longer created for "Already Resolved" and "Call Not Connected" cases, lowering reported ticket volume from April onward.
- **Weight discrepancy:** a penalty mechanism has been introduced to drive better adherence to weight-discrepancy capture.
- **Damage%** is tracked offline (not from an automated system).
- **Health/SLOs:** only defined for two of four Health metrics — Uptime SLO 99.9%, error-rate SLO ≤0.5%; latency P95 and L4-ticket rows have no SLO set.
- **L4 tickets** (social-media/mystery-shopping escalations) are handled via "High touch OLC by Ops team" — OLC is not expanded in the doc; instrumentation for this metric "needs to be built."

---

## Narrative-only sections

- **`## Product Context`** — the only section in the document carrying no metric/number at all. Five bullet points describing PTL's pre-PMF, operationally-assisted state (see Business context above for full text). This is the single clearest place in the doc where the business reasons in prose without a number behind it.

(Every other section is a metrics table; even where the "Insights/Observations" column carries substantial prose, it is always attached 1:1 to a specific numeric metric row, so those are not counted as narrative-only sections per the task's definition.)

---

## Contradictions / open items

1. **UNRESOLVED — column header typo:** Every single table (Demand, Marketplace, Supply, Health) has trailing-month columns in the order Apr-26, Mar-26, **Feb-25**, Jan-26, Dec-25, Nov-25, Oct-25. "Feb-25" sits chronologically between Mar-26 and Jan-26, so it is almost certainly meant to be "Feb-26" — but the doc literally says "Feb-25" everywhere. Recorded verbatim as `Feb-25[sic]` throughout this extract.
2. **UNRESOLVED — NPS series not comparable across a scale break:** Customer NPS/Sean Ellis (Business) is 53.85 in Apr-26 but 4.42–4.46 in every prior month shown, because the doc states the calculation approach changed mid-April (from a weighted 1–5 rating average to a real Promoter−Detractor NPS score, range −100 to 100). The Apr-26 figure and all prior figures are on different scales and should not be trended together.
3. **UNRESOLVED — narrative vs. data mismatch:** L1: First Contact Resolution% is annotated "Stable" in Insights, but Dec-25 = 21.5% is a sharp outlier against surrounding months in the 49–65% range.
4. **UNRESOLVED — self-contradictory narrative:** L1: Return trip% insight states both "There is slight dip from Feb to Mar to Apr" and, in the same cell, that return-vehicle visibility "resulted in 1pp jump in Mar" — a dip and a jump are asserted for the same Feb→Mar transition.
5. **Possible mismatch, not resolved:** L1: Median time to book by business user carries the insight text "Repeat order share has increased from 69% in Mar to 71.28% in Apr," which reads as unrelated to booking time and looks like it may belong to a different metric row.
6. **Incomplete source content:** L1: Earnings per Trip insight text is truncated mid-sentence: "Change in the " — the doc itself cuts off here, not an extraction error.
7. **Known gap, not a contradiction — several metrics have no product/instrumentation yet** and are marked NA/blank with an explicit doc note: Acceptance rate (batches accepted by Owners), % of organic allocation, Reallocation rate, Median days onboarding-to-first-trip, Partner NPS, Support tickets per trip %, L4 tickets. Batching engine and product-led supply are both explicitly targeted for Q2 (dev) / Q3 (release).
8. **Data-quality flag from doc itself:** April figures for "On time Pickup + On time Delivery," "On Time Pickup," and "On time Delivery" are each footnoted "*April month data got corrupted. Rest months are correct*" — so the Apr-26 values for these three rows are doc-flagged as unreliable, not something I am asserting.
9. **Minor formatting inconsistency:** Average Order Value Apr-26 is written "2920" (no thousands separator) while every other month uses a comma ("2,834" etc.) — transcribed exactly as written.
10. **Minor gap:** Health-section Dec-25/Nov-25/Oct-25 Uptime cells show only the row labels ("PartLoad-Ktor Server:PartLoad-Job Server:") with no values filled in.
