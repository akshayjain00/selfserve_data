# P5b — Amplitude Verification of 7 Catalogue Metrics

Project confirmed: PTL app = `customer-platform-prod`, appId **773228** (org `porter-in`, orgId 392987), verified via `get_amplitude_context`. This is the same appId the task hypothesized, now confirmed rather than assumed.

Org-level caveat (from org AI context, restated per task instructions): "Migrated from Mixpanel to Amplitude starting January 1, 2026. Reliable data begins ~January 2026; historical data may be incomplete." Any chart below with `createdAt`/`lastModified` timestamps in Jan 2026 or later is post-migration; none of the retrieved chart definitions themselves encode date ranges before Jan 2026 (most use rolling "Last 30/6 Months" windows), but any historical-trend read from these charts should still be treated as unreliable before ~Jan 2026 per the org caveat.

Method note: chart definitions were fetched via `get_charts` (by ID) and `get_from_url`, and candidates for un-recorded/unresolvable metrics were located via `search` (entityType CHART). No chart was queried/executed — only definitions were read, per the read-definition-first instruction. No cohort, dashboard, or annotation was created or modified.

---

## #3 — PTL Awareness Rate amongst Porter Business MAU

**Chart ID recorded in catalogue:** none.
**Search result:** **NOT FOUND.** Searched `"PTL Awareness Rate"`, `"PTL Awareness"`, `"Awareness Rate Porter Business MAU"` against CHART entities (100 results returned, deduplicated via RRF). Zero results contain "awareness" (or any close synonym) in the chart name — confirmed by an explicit case-insensitive filter for `"awar"` across all 100 results, which matched nothing. Top-scoring results were unrelated PTL funnel/conversion charts (e.g., `eq64vca4` "PTL VSS Shown ---> PTL VSS Confirmed (BLR)", `x9yo5m6q` "PTL Enabled %"), all with low relevance scores (≤0.18), i.e. keyword-overlap only ("PTL"), not semantic matches on "awareness."

**Verdict: NOT FOUND — no confident match. Do not substitute.** This metric may not exist as a saved Amplitude chart, may live in a dashboard not surfaced by this search, or may be computed outside Amplitude entirely (e.g., Snowflake/Metabase, despite the catalogue tagging it "Amplitude"). Flagging for orchestrator follow-up rather than guessing.

---

## #4 — VSS Top-of-Funnel — PTL Serviceable Sessions

**Chart ID:** `3jh9upju` — **FOUND.**

- **Chart name (as saved):** "TOF (PTL Shown on VSS)"
- **Type:** `eventsSegmentation`, visualization `kpi` (single overall-value KPI), metric = `uniques`
- **Event:** `vehicleselectionscreen_vehicles_loaded`
- **Filter:** User-level event filter, `subprop_key: "vehicle_ids_seq"`, op `contains`, value `["1159"]` — i.e., counts unique occurrences where the vehicle-options list loaded on the selection screen includes vehicle id **1159** (the PTL vehicle option code, consistent with its use as the "PTL" filter value across the other charts below).
- **Segment:** "All Users" (no business/persona filter applied on this chart — the catalogue's stated metric name doesn't specify a persona cut either, so this is consistent).
- **countGroup:** `User` — meaning the uniques are **unique users**, not sessions. The chart's own title says "VSS Shown" and the catalogue calls it "Serviceable Sessions" — worth flagging: the underlying Amplitude computation here is user-based, not session-based, which is a subtle terminology mismatch worth resolving if session-level counts matter downstream.
- Range: "Last 30 Days", rolling — no fixed historical range that would trip the pre-2026 caveat.

**Match to catalogue definition:** Good match on intent (VSS top-of-funnel, PTL-serviceable). Caveat: metric counts **users**, not **sessions**, despite catalogue/chart naming implying sessions.

**VSS literal:** event type is literally `vehicleselectionscreen_vehicles_loaded` — confirms VSS = "Vehicle Selection Screen" (spelled out in the raw event name).

**Confidence: HIGH** (chart exists, definition is legible and plausibly matches; one naming nuance flagged above).

---

## #5 — PTL Serviceable VSS as % of Overall Porter Sessions on VSS

**Chart ID recorded in catalogue:** `42065`.
**Result: NOT FOUND.**
- `get_charts(chartIds: ["42065"])` → returned `null` for this ID.
- `get_from_url` against `https://app.amplitude.com/analytics/porter-in/chart/42065` → parsed successfully as a chart-URL, but `charts: [null]` — the ID does not resolve to any object in this Amplitude org.
- Name-search for `"PTL Serviceable VSS as % of Overall Porter Sessions"` / `"Serviceable VSS Overall Porter Sessions"` surfaced no confident match — best-scoring results (`eq64vca4`, `3zh6l68b` "VSS Sessions", `4c57u8lz`/`6mrxbl45` "Overall - Location SS to VSS") are topically adjacent (VSS-related, "overall" in name) but none states this specific ratio, and scores are low (≤0.16, i.e. weak keyword overlap only).

**Verdict: NOT FOUND — the numeric ID `42065` is not a valid Amplitude chart ID, and no name-based candidate is a confident match.** Numeric IDs of this shape (5-digit integer) don't match the ID scheme seen on every chart actually resolved in this session (8-character alphanumeric strings, e.g. `3jh9upju`, `eq64vca4`, `l9brfm70`). This strongly suggests `42065` is a **leftover reference from the pre-migration platform (Mixpanel used numeric board/insight IDs)** that was never re-mapped to an Amplitude chart ID after the Jan 2026 migration — a useful finding in its own right, not just an absence.

---

## #6 — PTL Card Tap Rate in Serviceable Sessions (Business Users)

**Chart ID recorded in catalogue:** `49312`.
**Result: NOT FOUND.**
- `get_charts(chartIds: ["49312"])` → `null`.
- `get_from_url` against `https://app.amplitude.com/analytics/porter-in/chart/49312` → parsed as chart URL, `charts: [null]`.
- Name-search for `"PTL Card Tap Rate Serviceable Sessions"` / `"Card Tap Rate business users"` surfaced no confident match. Closest topically-relevant candidates (`jdk88x2c` "Home page to PTL card", `rl1tpek5` "Home screen PTL card click funnel", `awgb8hli` "PTL card click to other booking flow") are about the **homescreen** PTL card, not a VSS/serviceable-session-scoped tap rate, and none mentions "serviceable" or business-user segmentation in its name. Scores are low (≤0.08).

**Verdict: NOT FOUND — same pattern as #5.** Numeric ID `49312` does not exist as an Amplitude chart, and no candidate confidently matches the catalogue's stated definition (a card-tap-rate scoped to *serviceable* sessions, business users). Same leftover-Mixpanel-ID hypothesis applies.

---

## #7 — PTL Selection Rate vs FTL

**Chart ID:** `gjvatdh3` — **FOUND.**

- **Chart name (as saved):** "% of OS sessions where PTL was selected / % of sessions where either PTL or FTL was selected by business users (>100km cut)"
- **Type:** `eventsSegmentation`, visualization `line`, metric = `formula`: **`SESSIONTOTALS(B) / SESSIONTOTALS(A)`**
- **Event A (denominator):** `vehicleselectionscreen_confirm_clicked`, filtered where User-level `vehicle_id` **contains** one of `["100","101","102","103","104","105","106","107","108","111","112","114","1141","1150","1151","1152","132","1159"]` — a broad list of vehicle-id codes, of which `1159` (PTL) is one member; the rest are presumably other truckload/FTL vehicle types. Also filtered on a `lookup`-type property keyed `"26356"` **≥ "100"** (an opaque numeric lookup-property ID — plausibly a distance-in-km field, consistent with the "(>100km cut)" in the chart title, but not confirmable from the definition alone without resolving that lookup property's schema name).
- **Event B (numerator):** same event, filtered where `vehicle_id` **is** `"1159"` (PTL only) plus the same `≥100` lookup filter.
- **Segment:** `business` — defined by condition `gp:c360_persona is "business"` (User-level group property `c360_persona`).
- Range: "Last 6 Months", rolling.

**Match to catalogue definition:** Good conceptual match — this is PTL-selected sessions as a fraction of (PTL + other-truckload "FTL") sessions, scoped to business users and a >100km distance cut, matching "#7 PTL Selection Rate vs FTL."

**FTL literal-string check:** **Not found.** "FTL" does not appear as a literal event name, property name, or property value anywhere in this chart's definition. The concept is represented only implicitly, as a specific enumerated list of `vehicle_id` codes (`100,101,...,1159,...`) grouped together in the denominator filter — the chart's human-readable title uses "FTL" as a label, but the underlying Amplitude taxonomy has no field or value literally named "FTL". This is a real (negative) data point for the open VSS/FTL-acronym question: at least in this project's taxonomy, "FTL" is not a defined term — it's an author's shorthand for "any vehicle_id in this list other than PTL's 1159."

**Confidence: HIGH** on chart identity/formula; **inconclusive** on the exact semantic meaning of `vehicle_id` codes and the lookup-property `26356` (would need `get_properties`/`get_events` taxonomy lookups to confirm, which was out of scope here — not executed since it wasn't required to answer computability).

---

## #8 — Outstation Search Rate (Business Users)

**Chart ID:** `l9brfm70` — **FOUND.**

- **Chart name (as saved):** "Outstation search rate"
- **Type:** `eventsSegmentation`, visualization `line`, metric = `formula`: **`UNIQUES(A) / UNIQUES(B)`**
- **Event A (numerator):** `ce:OS Vehicle Loaded - VSS` — a **custom event** (the `ce:` prefix denotes a custom/computed event in Amplitude), no filters.
- **Event B (denominator):** `vehicleselectionscreen_vehicles_loaded`, no filters.
- **Segment:** `business` — `gp:c360_persona is "business"` (same persona property as #7).
- Range: "Last 6 Months", rolling.

**Match to catalogue definition:** Good match — "Outstation Search Rate (Business Users)" = unique users who load the outstation vehicle option on VSS, divided by all unique users who load VSS at all, restricted to the business persona. Matches catalogue naming and intent directly (no discrepancy flagged).

**VSS literal:** confirms VSS again — both the custom event name `ce:OS Vehicle Loaded - VSS` (literal "VSS" suffix) and the raw event `vehicleselectionscreen_vehicles_loaded` point to the same "Vehicle Selection Screen" expansion already established under #4.

**Confidence: HIGH.**

---

## #18 — Median Time to Book (VSS to Order Placed)

**Chart ID recorded in catalogue:** none.
**Search result:** candidate found, but **not a confident/exact match** — flagging as a plausible lead, not a confirmed identification.

- Searched `"Median Time to Book"`, `"Time to Book VSS Order Placed"`, `"Time to Book"` (96 CHART results). Nothing named literally "Median Time to Book" or "VSS to Order Placed." Best name-level candidate: `9soyf565` **"Median Booking Time"**.
- Fetched its definition: **Type:** `funnels`, view `timeToConvert` (i.e., a time-to-convert / median-time funnel — matches "Median" semantically), metric `OVER_TIME`.
  - **Step 1:** `vehicleselectionscreen_vehicles_loaded`, filtered User-level `vehicle_ids_seq` **is** `"1159"` (PTL) — i.e., VSS load where PTL specifically is the (sole?) option shown.
  - **Step 2:** `ptlbookingdetailspage_booknow_clicked` — a "book now clicked" tap on the PTL booking-details page.
  - Segment: "All Users." Conversion window: 86,400 seconds (24h). Range: "Last 6 Months."
- **Discrepancy vs. catalogue's stated definition:** the catalogue names this metric "VSS to **Order Placed**," but the chart's second funnel step is **`ptlbookingdetailspage_booknow_clicked`** ("book now" click), not an order-placed/order-confirmed event. Clicking "book now" and an order actually being placed/confirmed are plausibly different, later moments in the flow (e.g., there could be a payment or confirmation step after the click). This is a real terminology/step gap, not just a naming variant.
- A second candidate, `zvmypzfo` ("Time to convert -Location -> Order Placed[1 D]"), does end on an "Order Placed"-named event (`order_confirm_page_pnm_viewed`), but its start event (`location_page_pnm_viewed`) and end event are both **PnM-vertical** events, not PTL/VSS — ruled out as irrelevant to this PTL metric.

**Verdict: NOT CONFIRMED.** `9soyf565` "Median Booking Time" is a plausible, PTL-specific, VSS-anchored time-to-convert chart and the closest thing found, but its terminal event ("book now clicked") does not literally match "Order Placed" in the catalogue's metric name. Reporting this as a lead for the orchestrator to confirm with the metric's original author, not as a settled identification — per instructions, not substituting a similar-sounding chart as if confirmed.

**VSS literal:** step 1 event `vehicleselectionscreen_vehicles_loaded` again confirms VSS = Vehicle Selection Screen.

**Confidence: LOW-MEDIUM** (plausible candidate located, but a real step-definition gap between "book now clicked" and "order placed" remains unresolved).

---

## Cross-cutting notes

- **VSS expansion — resolved with high confidence:** VSS = "Vehicle Selection Screen." Evidence: raw event type `vehicleselectionscreen_vehicles_loaded` (used in #4, #8, and the #18 candidate) and custom event `ce:OS Vehicle Loaded - VSS` (used in #8). Both spell out the full phrase or use "VSS" directly as a suffix on the same screen concept.
- **FTL expansion — NOT resolved / not literally present:** searched all retrieved chart definitions; "FTL" never appears as an event name, property name, or property value. It exists only as a human-authored label in chart title #7, standing in for an enumerated list of `vehicle_id` codes other than PTL's `1159`. This is a genuine negative finding for the open acronym question, not a gap in searching.
- **Numeric vs. alphanumeric chart IDs:** every chart actually resolved in this Amplitude org uses an 8-character alphanumeric ID (e.g. `3jh9upju`, `gjvatdh3`, `l9brfm70`, `eq64vca4`, `9soyf565`). The two catalogue-recorded numeric IDs (`42065`, `49312`) don't fit that pattern and resolve to nothing — likely stale references to the pre-migration (Mixpanel) platform's numeric IDs that were never updated post-Jan-2026 migration.
