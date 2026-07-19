# Dry-run test report — 2026-07-19

## Answerable questions (resolution + SQL render)

- **PASS** `leads_overall` 2026-05 — "How many leads did we get in May 2026?"
- **PASS** `leads_app` 2026-05 — "App leads in May 2026?"
- **PASS** `leads_desktop` 2026-04 — "How many desktop website leads in April 2026?"
- **PASS** `leads_mobile` 2026-05 — "Mobile website leads for May 2026"
- **PASS** `leads_others` 2026-05 — "Leads from other channels in May 2026?"
- **PASS** `leads_overall` 2026-07  [MTD-labeled] — "Total leads in July 2026?"
- **PASS** `orders_overall` 2026-05 — "How many orders were booked in May 2026?"
- **PASS** `orders_app` 2026-05 — "Orders from the app in May 2026?"
- **PASS** `orders_desktop` 2026-04 — "Desktop website orders in April 2026?"
- **PASS** `orders_mobile` 2026-05 — "mweb orders in May 2026?"
- **PASS** `orders_others` 2026-04 — "Orders from other channels in April 2026?"
- **PASS** `orders_overall` 2026-07  [MTD-labeled] — "Bookings in July 2026?"
- **PASS** `conversion_overall` 2026-05 — "What was the conversion rate in May 2026?"
- **PASS** `conversion_app` 2026-05 — "App conversion rate in May 2026?"
- **PASS** `conversion_desktop` 2026-04 — "Desktop conversion in April 2026?"
- **PASS** `pct_orders_app` 2026-05 — "What share of app orders did we have in May 2026?"
- **PASS** `pct_orders_website` 2026-05 — "Website order share in May 2026?"
- **PASS** `pct_orders_others` 2026-05 — "Others order share in May 2026?"
- **PASS** `tpo_overall` 2026-05 — "What was TPO in May 2026?"
- **PASS** `tpo_overall` 2026-05 — "Tickets per order in May 2026?"
- **PASS** `tpo_vendor_raised` 2026-05 — "Vendor raised TPO in May 2026?"
- **PASS** `tpo_pre_trip` 2026-04 — "Pre-trip TPO in April 2026?"
- **PASS** `orders_base` 2026-05 — "How many orders in the TPO base in May 2026?"
- **PASS** `tpo_cancelled` 2026-05 — "TPO for cancelled orders in May 2026?"
- **PASS** `p80_sup_assigned_to_trip_started` 2026-05 — "p80 supervisor assigned to trip started in May 2026?"
- **PASS** `p80_trip_started_to_shifting_started` 2026-05 — "p80 trip started to shifting started in May 2026?"
- **PASS** `p80_shifting_started_to_pickup_complete` 2026-05 — "p80 shifting started to pickup complete in May 2026?"
- **PASS** `p80_pickup_complete_to_order_complete` 2026-05 — "p80 pickup complete to order complete in May 2026?"
- **PASS** `p80_trip_duration` 2026-05 — "What was the p80 trip duration in May 2026?"
- **PASS** `pct_orders_edited` 2026-05 — "percent orders edited in May 2026?"
- **PASS** `no_of_successful_edits` 2026-05 — "number of successful edits in May 2026?"
- **PASS** `pct_support_edited_orders` 2026-05 — "percent support edited orders in May 2026?"
- **PASS** `location_adoption_pct` 2026-05 — "location edit adoption in May 2026?"
- **PASS** `pct_orders_location_modified` 2026-05 — "percent orders location modified in May 2026?"
- **PASS** `items_adoption_pct` 2026-05 — "items edit adoption in May 2026?"
- **PASS** `addons_adoption_pct` 2026-05 — "addons edit adoption in May 2026?"
- **PASS** `slot_adoption_pct` 2026-05 — "slot edit adoption in May 2026?"
- **PASS** `edits_per_order` 2026-05 — "edits per order in May 2026?"
- **PASS** `pct_edits_after_shifting_started` 2026-05 — "percent edits after shifting started in May 2026?"

## Refusal cases (must NOT answer)

- **PASS** [question] "City-wise leads in Bangalore in May 2026?" (2026-05) — resolver said: "question mentions 'city' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "Weekly orders trend for May 2026?" (2026-05) — resolver said: "question mentions 'weekly' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "median tickets per order in May 2026?" (2026-05) — resolver said: "question mentions 'median' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "Vendor wise TPO in May 2026?" (2026-05) — resolver said: "question mentions 'vendor wise' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "median trip duration in May 2026?" (2026-05) — resolver said: "question mentions 'median' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "p50 trip duration in May 2026?" (2026-05) — resolver said: "question mentions 'p50' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "p90 trip duration in May 2026?" (2026-05) — resolver said: "question mentions 'p90' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "trip duration by vendor in May 2026?" (2026-05) — resolver said: "question mentions 'by vendor' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [metric_blocked] "ota_pct" (2026-05) — ota readiness=blocked, built=False
- **PASS** [metric_unknown] "totally_made_up_metric" (2026-05) — 'totally_made_up_metric' correctly absent from the catalog — gate() would refuse (this tool never improvises metrics)
- **PASS** [future_month] "tpo_overall" (2027-01) — 2027-01 correctly detected as future

## New-section structural checks (p80_durations, order_edits)

- **PASS** p80_durations render — AS month present, read-only, allow-listed tables
- **PASS** order_edits render — AS month present, read-only, allow-listed tables

## `--metric`-only metrics (no NL alias)

- **PASS** p50_trip_duration — in catalog, produced as a column, no NL alias
- **PASS** p80_vendor_accepted_to_sup_assigned — in catalog, produced as a column, no NL alias

## Summary: 54 passed, 0 failed