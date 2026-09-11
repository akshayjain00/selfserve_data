# Dry-run test report — 2026-09-04

## Answerable questions (resolution + SQL render)

- **PASS** `leads_overall_intra_city` 2026-05 — "How many leads did we get in May 2026?"
- **PASS** `leads_app` 2026-05 — "App leads in May 2026?"
- **PASS** `leads_desktop` 2026-04 — "How many desktop website leads in April 2026?"
- **PASS** `leads_mobile` 2026-05 — "Mobile website leads for May 2026"
- **PASS** `leads_others` 2026-05 — "Leads from other channels in May 2026?"
- **PASS** `leads_overall_intra_city` 2026-07 — "Total leads in July 2026?"
- **PASS** `orders_overall` 2026-05 — "How many orders were booked in May 2026?"
- **PASS** `orders_app` 2026-05 — "Orders from the app in May 2026?"
- **PASS** `orders_desktop` 2026-04 — "Desktop website orders in April 2026?"
- **PASS** `orders_mobile` 2026-05 — "mweb orders in May 2026?"
- **PASS** `orders_others` 2026-04 — "Orders from other channels in April 2026?"
- **PASS** `orders_overall` 2026-07 — "Bookings in July 2026?"
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
- **PASS** `ota_pct` 2026-05 — "What was the on time arrival percentage in May 2026?"
- **PASS** `ota_pct` 2026-04 — "OTA in April 2026?"
- **PASS** `ota_on_time_orders` 2026-05 — "How many orders were on time in May 2026?"
- **PASS** `ota_delay_orders` 2026-05 — "How many orders were delayed in May 2026?"
- **PASS** `ota_delay_gt_60_mins_orders` 2026-05 — "Orders delayed more than 60 minutes in May 2026?"
- **PASS** `ota_delay_gt_60_mins_pct` 2026-05 — "Percent orders delayed over 60 minutes in May 2026?"
- **PASS** `ota_total_completed_orders` 2026-05 — "How many orders in the ota base in May 2026?"
- **PASS** `ota_unset_orders` 2026-05 — "Orders with no shifting started event in May 2026?"
- **PASS** `gac_ctr_pct` 2026-05 — "Get a call CTR in May 2026?"
- **PASS** `gac_ctr_pct` 2026-04 — "What was the get a call click through rate in April 2026?"
- **PASS** `weekend_order_share_pct` 2026-05 — "Weekend order contribution in May 2026?"
- **PASS** `cac_post_trip_started_pct` 2026-05 — "CAC post trip started in May 2026?"
- **PASS** `active_vendor_count` 2026-05 — "How many active vendors in May 2026?"
- **PASS** `allocation_pct` 2026-05 — "What was the allocation percentage in May 2026?"
- **PASS** `allocation_time_p80_minutes` 2026-05 — "Allocation time p80 in May 2026?"
- **PASS** `reschedule_pct` 2026-05 — "Reschedule rate in May 2026?"
- **PASS** `withdrawal_failure_pct` 2026-05 — "Withdrawal failure rate in May 2026?"
- **PASS** `vendor_tpo` 2026-05 — "Vendor tpo raw pipeline in May 2026?"
- **PASS** `pct_orders_with_any_addon` 2026-05 — "Overall add-on adoption in May 2026?"
- **PASS** `pct_orders_with_packing` 2026-05 — "Packing addon adoption in May 2026?"
- **PASS** `completion_score_pct` 2026-05 — "Overall completion score in May 2026?"
- **PASS** `nps` 2026-05 — "Overall NPS in May 2026?"
- **PASS** `aov` 2026-05 — "Average order value in May 2026?"
- **PASS** `pct_orders_with_surge` 2026-05 — "Percent orders with surge in May 2026?"
- **PASS** `revenue_pct_goldplus` 2026-05 — "Vendor earnings goldplus in May 2026?"

## Refusal cases (must NOT answer)

- **PASS** [question] "City-wise leads in Bangalore in May 2026?" (2026-05) — resolver said: "question mentions 'city' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "Weekly orders trend for May 2026?" (2026-05) — resolver said: "question mentions 'weekly' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "median tickets per order in May 2026?" (2026-05) — resolver said: "question mentions 'median' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "Vendor wise TPO in May 2026?" (2026-05) — resolver said: "question mentions 'vendor wise' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "median trip duration in May 2026?" (2026-05) — resolver said: "question mentions 'median' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "p50 trip duration in May 2026?" (2026-05) — resolver said: "question mentions 'p50' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "p90 trip duration in May 2026?" (2026-05) — resolver said: "question mentions 'p90' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [question] "trip duration by vendor in May 2026?" (2026-05) — resolver said: "question mentions 'by vendor' — the catalog is monthly, PnM-wide only (no city/vendor cuts, no weekly/daily grain, no medians/percentiles for these sections)"
- **PASS** [metric_unknown] "totally_made_up_metric" (2026-05) — 'totally_made_up_metric' correctly absent from the catalog — gate() would refuse (this tool never improvises metrics)
- **PASS** [future_month] "tpo_overall" (2027-01) — 2027-01 correctly detected as future

## New-section structural checks (all sections built after iteration-3)

- **PASS** p80_durations render — AS month present, read-only, allow-listed tables
- **PASS** order_edits render — AS month present, read-only, allow-listed tables
- **PASS** ota render — AS month present, read-only, allow-listed tables
- **PASS** gac_ctr render — AS month present, read-only, allow-listed tables
- **PASS** weekend render — AS month present, read-only, allow-listed tables
- **PASS** cac_post_trip render — AS month present, read-only, allow-listed tables
- **PASS** vendor_earnings_pctl render — AS month present, read-only, allow-listed tables
- **PASS** allocation render — AS month present, read-only, allow-listed tables
- **PASS** wallet render — AS month present, read-only, allow-listed tables
- **PASS** vendor_tpo_top5 render — AS month present, read-only, allow-listed tables
- **PASS** addon render — AS month present, read-only, allow-listed tables
- **PASS** completion render — AS month present, read-only, allow-listed tables
- **PASS** fare render — AS month present, read-only, allow-listed tables
- **PASS** vendor_earnings_bucket render — AS month present, read-only, allow-listed tables

## `--metric`-only metrics (no NL alias)

- **PASS** p50_trip_duration — in catalog, produced as a column, no NL alias
- **PASS** p80_vendor_accepted_to_sup_assigned — in catalog, produced as a column, no NL alias
- **PASS** p50_earnings_per_vendor — in catalog, produced as a column, no NL alias
- **PASS** p80_earnings_per_vendor — in catalog, produced as a column, no NL alias
- **PASS** p50_orders_per_vendor — in catalog, produced as a column, no NL alias
- **PASS** p80_orders_per_vendor — in catalog, produced as a column, no NL alias
- **PASS** withdrawals_per_vendor — in catalog, produced as a column, no NL alias
- **PASS** recharges_per_vendor — in catalog, produced as a column, no NL alias
- **PASS** p50_withdrawal_amount — in catalog, produced as a column, no NL alias
- **PASS** p50_recharge_amount — in catalog, produced as a column, no NL alias
- **PASS** median_fare_increase_amt — in catalog, produced as a column, no NL alias
- **PASS** median_fare_decrease_amt — in catalog, produced as a column, no NL alias

## Column-production check — every metric id in ('weekend', 'cac_post_trip', 'vendor_earnings_pctl', 'allocation', 'wallet', 'vendor_tpo_top5', 'addon', 'completion', 'fare', 'vendor_earnings_bucket')

- **PASS** weekend (1 metrics) — every metric id produced
- **PASS** cac_post_trip (1 metrics) — every metric id produced
- **PASS** vendor_earnings_pctl (6 metrics) — every metric id produced
- **PASS** allocation (33 metrics) — every metric id produced
- **PASS** wallet (6 metrics) — every metric id produced
- **PASS** vendor_tpo_top5 (6 metrics) — every metric id produced
- **PASS** addon (7 metrics) — every metric id produced
- **PASS** completion (3 metrics) — every metric id produced
- **PASS** fare (14 metrics) — every metric id produced
- **PASS** vendor_earnings_bucket (5 metrics) — every metric id produced

## Summary: 110 passed, 0 failed