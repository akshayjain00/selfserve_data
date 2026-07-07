# Dry-run test report — 2026-07-07

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

## Refusal cases (must NOT answer)

- **PASS** [question] "City-wise leads in Bangalore in May 2026?" (2026-05) — resolver said: "question mentions 'city' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "Weekly orders trend for May 2026?" (2026-05) — resolver said: "question mentions 'weekly' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "median tickets per order in May 2026?" (2026-05) — resolver said: "question mentions 'median' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "Vendor wise TPO in May 2026?" (2026-05) — resolver said: "question mentions 'vendor wise' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [metric_blocked] "ota_pct" (2026-05) — ota readiness=blocked, built=False
- **PASS** [metric_not_built] "p80_trip_duration_mins" (2026-05) — p80 metric ids not present in v0 registry; section marked not_built
- **PASS** [future_month] "tpo_overall" (2027-01) — 2027-01 correctly detected as future

## Summary: 31 passed, 0 failed