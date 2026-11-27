```text
What this is:      Reconciliation of the HCV intracity ops report against dashboard 6406's card SQL for one full week.
Who it's for:      The report owner, checking that the report ties to the dashboard.
What to do with it: Accept or question the report's Demand, Fulfilment % and Revenue.
Status:            draft
```

# Reconciliation vs dashboard 6406 — 2026-11-16 to 2026-11-22

Scope on both sides: Tier 1, serviceability segment Vanilla (intracity).

| Metric | Report | Dashboard 6406 card | Difference | Gap | Card |
|---|---:|---:|---:|---:|---|
| Demand | 1,54,961 | 1,54,961 | 0 | +0.00% | 55586 |
| Completed orders | 93,255 | 93,255 | 0 | +0.00% | 55586 |
| Fulfilment % | 60.18% | 60.18% | +0.00pp |  | 55586 |
| Revenue | ₹17.86 Cr | ₹17.99 Cr | −₹12.15 L | -0.68% | 55587 |
| Completed orders (revenue card) | 93,255 | 93,258 | −3 | -0.00% | 55587 |

Unrounded revenue: report 178639614.00, card 179854239.83.

Card 55587 does not use the report's revenue definition: it reads raw OMS and schedule-order tables, sums the final fare from `order_fares`, and dates orders on `created_at`. The report follows hcv-data: `sum(FO_CUSTOMER_FARE_WITHOUT_PREVIOUS_DUE)` on completed orders in `HCV_OVERALL_DEMAND_MART`, dated on `order_time`.

Sources: `data/hcv_daily_orders_*.json` (report side) and `docs/reconciliation/card_*_2026-11-16_2026-11-22.json` (card side, verbatim Snowflake responses including their query ids).
