# HCV Metrics — Final Query Pack

**Scope / common filters (unless noted):**
- Table: `prod_eldoria.mart.hcv_overall_demand_mart` (order-level)
- Period: **May–Jul 2026**, reported monthly (Jul is a partial month)
- Tier: **Tier 1** only (`dim_geo_regions.tier = 'Tier 1'`)
- Vehicle: `vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')`
- Test customer excluded: `customer_mobile <> '0000000001'`
- Status: `COALESCE(order_status, 5) IN (4,5)` — NULL treated as 5 (cancelled)
- Distance bucket: `< 100km` / `>= 100km` / `unknown`, from the base table below

**Key definitions:**
- Allocation uses **`fo_driver_id`** (fact-orders driver), not `driver_id`
- Allocated% = allocated / total placed
- FF% (fulfilment) = completed (status 4) / total placed
- E-FF% (effective fulfilment) = completed / (total placed − customer cancelled), where customer cancelled = status 5 with cancel-reason `attribution = 'customer'`
- Unique FF% = completed / unique (deduped) demand
- Duplicate order (for unique demand): same customer, pickup & drop within 100m, next order within 60 min, status 5
- Category: 10ft is split by NCR (`geo_region_id = 2`) vs non-NCR; allocation/FF/unique-FF also keep a 10ft overall row; ATA keeps NCR/non-NCR only
- Revenue is OMS-only (a completed trip always exists in OMS); `final_total_fare` = fare_type 2, current

---

## 0. Base table — `mbr_mapping_v2` (run first)

Row-level order → estimated distance (km) for May–Jul. FO distance from `fact_order_fares` (fare_type 1, current); SO distance from `fact_quotations` via quotation UUID. Both fields are already in km.

```sql
create or replace table dev_eldoria.sandbox.mbr_mapping_v2 as
WITH m AS (
    SELECT
        d.unique_id,
        DATE_TRUNC('month', d.order_time)::date AS order_month,
        d.order_status,
        CASE WHEN d.order_status = 4 THEN 1 ELSE 0 END AS completed_flag,
        d.fo_order_id,
        d.so_quotation:quotation_uuid::string AS quotation_uuid
    FROM prod_eldoria.mart.hcv_overall_demand_mart d
    JOIN prod_eldoria.core.dim_geo_regions g ON d.geo_region_id = g.geo_region_id
    WHERE d.customer_mobile <> '0000000001'
      AND d.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND COALESCE(d.order_status, 5) IN (4, 5)
      AND d.order_time >= DATE '2026-05-01'
      AND d.order_time <  DATE '2026-08-01'
),
fo_dist AS (
    SELECT order_id, MAX(travel_distance) AS est_distance_km
    FROM prod_eldoria.core.fact_order_fares
    WHERE fare_type = 1 AND is_current
      AND created_at >= '2026-04-25' AND created_at < '2026-08-02'
    GROUP BY order_id
),
so_dist AS (
    SELECT uuid, MAX(google_distance_in_kms) AS est_distance_km
    FROM prod_eldoria.core.fact_quotations
    WHERE quotations_creation_time >= '2026-03-01' AND quotations_creation_time < '2026-08-02'
    GROUP BY uuid
)
SELECT
    m.unique_id,
    m.order_month,
    m.order_status,
    m.completed_flag,
    m.fo_order_id,
    m.quotation_uuid,
    f.est_distance_km AS est_distance_km_fo,
    s.est_distance_km AS est_distance_km_so,
    COALESCE(f.est_distance_km, s.est_distance_km) AS est_distance_km
FROM m
LEFT JOIN fo_dist f ON f.order_id = m.fo_order_id
LEFT JOIN so_dist s ON s.uuid     = m.quotation_uuid;
```

---

## 1. Revenue + completed orders (OMS-only, month × distance)

```sql
WITH dist AS (
    SELECT fo_order_id AS id, MAX(est_distance_km) AS est_distance_km
    FROM dev_eldoria.sandbox.mbr_mapping_v2
    WHERE fo_order_id IS NOT NULL
    GROUP BY fo_order_id
),
oms AS (
    SELECT
        date_trunc('month', o.created_at + interval '330 minutes')::date AS order_month,
        o.id
    FROM prod_curated.oms_public.orders o
    JOIN prod_eldoria.core.dim_vehicles    v ON o.vehicle_id    = v.vehicle_id
    JOIN prod_eldoria.core.dim_geo_regions g ON g.geo_region_id = o.geo_region_id
    WHERE date(o.created_at + interval '330 minutes') >= '2026-05-01'
      AND date(o.created_at + interval '330 minutes') <= '2026-07-31'
      AND o.deleted_at IS NULL
      AND o.order_type = 0
      AND o.customer_mobile <> '0000000001'
      AND o.status = 4
      AND v.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND g.tier = 'Tier 1'
),
fare AS (
    SELECT A.order_id,
        ROUND(SUM(CASE WHEN A.fare_type = 2 AND A.is_current
             THEN ceil(A.fare) + A.coupon_discount + A.referral_discount + A.subscription_discount END),2) AS final_total_fare
    FROM prod_curated.oms_public.order_fares A
    JOIN prod_curated.oms_public.orders o ON A.order_id = o.id
    WHERE date(o.created_at + interval '330 minutes') >= '2026-05-01'
      AND date(o.created_at + interval '330 minutes') <= '2026-07-31'
      AND A.is_current AND A.fare_type = 2
      AND o.deleted_at IS NULL AND o.order_type = 0
      AND o.customer_mobile <> '0000000001' AND o.status = 4
    GROUP BY A.order_id
)
SELECT
    o.order_month,
    CASE WHEN d.est_distance_km <  100 THEN '<100km'
         WHEN d.est_distance_km >= 100 THEN '>=100km'
         ELSE 'unknown' END AS distance_bucket,
    COUNT(DISTINCT o.id)    AS completed_order,
    SUM(f.final_total_fare) AS revenue,
    div0(SUM(f.final_total_fare), COUNT(DISTINCT o.id)) AS aov
FROM oms o
LEFT JOIN fare f ON o.id = f.order_id
LEFT JOIN dist d ON o.id = d.id
GROUP BY 1, 2
ORDER BY 1, 2;
```

---

## 2. Allocated% / FF% / E-FF% (month × category × distance)

```sql
WITH f AS (
    SELECT
        DATE_TRUNC('month', m.order_time)::date AS order_month,
        m.unique_id,
        m.geo_region_id,
        m.vehicle_mapping,
        m.fo_driver_id,
        COALESCE(m.order_status, 5) AS order_status,
        cr.attribution,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM prod_eldoria.mart.hcv_overall_demand_mart m
    JOIN prod_eldoria.core.dim_geo_regions g ON m.geo_region_id = g.geo_region_id
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON m.unique_id = mb.unique_id
    LEFT JOIN prod_eldoria.core.dim_cancel_reasons_attribution cr
           ON m.fo_cancel_reason_id = cr.cancel_reason_id
    WHERE m.customer_mobile <> '0000000001'
      AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND COALESCE(m.order_status, 5) IN (4, 5)
      AND m.order_time >= DATE '2026-05-01'
      AND m.order_time <  DATE '2026-08-01'
),
cat AS (
    SELECT order_month, distance_bucket, vehicle_mapping AS category, unique_id, fo_driver_id, order_status, attribution FROM f
    UNION ALL
    SELECT order_month, distance_bucket,
           CASE WHEN geo_region_id = 2 THEN '10ft - NCR' ELSE '10ft - non NCR' END,
           unique_id, fo_driver_id, order_status, attribution
    FROM f WHERE vehicle_mapping = '10ft'
),
agg AS (
    SELECT
        order_month, category, distance_bucket,
        COUNT(unique_id)                                                                         AS total_placed,
        COUNT(CASE WHEN fo_driver_id IS NOT NULL THEN unique_id END)                             AS orders_allocated,
        COUNT(CASE WHEN order_status = 4 THEN unique_id END)                                     AS completed_orders,
        COUNT(CASE WHEN order_status = 5 AND LOWER(attribution) = 'customer' THEN unique_id END) AS customer_cancelled
    FROM cat
    GROUP BY order_month, category, distance_bucket
)
SELECT
    order_month, category, distance_bucket,
    total_placed, orders_allocated, completed_orders, customer_cancelled,
    ROUND(orders_allocated / NULLIF(total_placed, 0), 4)                       AS allocated_pct,
    ROUND(completed_orders / NULLIF(total_placed, 0), 4)                       AS ff_pct,
    ROUND(completed_orders / NULLIF(total_placed - customer_cancelled, 0), 4)  AS e_ff_pct
FROM agg
ORDER BY order_month, category, distance_bucket;
```

---

## 2a. Allocated% / FF% / E-FF% (month × distance, overall — no category)

```sql
WITH b AS (
    SELECT
        DATE_TRUNC('month', m.order_time)::date AS order_month,
        m.unique_id,
        m.fo_driver_id,
        COALESCE(m.order_status, 5) AS order_status,
        cr.attribution,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM prod_eldoria.mart.hcv_overall_demand_mart m
    JOIN prod_eldoria.core.dim_geo_regions g ON m.geo_region_id = g.geo_region_id
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON m.unique_id = mb.unique_id
    LEFT JOIN prod_eldoria.core.dim_cancel_reasons_attribution cr
           ON m.fo_cancel_reason_id = cr.cancel_reason_id
    WHERE m.customer_mobile <> '0000000001'
      AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND COALESCE(m.order_status, 5) IN (4, 5)
      AND m.order_time >= DATE '2026-05-01'
      AND m.order_time <  DATE '2026-08-01'
),
agg AS (
    SELECT
        order_month, distance_bucket,
        COUNT(unique_id)                                                                         AS total_placed,
        COUNT(CASE WHEN fo_driver_id IS NOT NULL THEN unique_id END)                             AS orders_allocated,
        COUNT(CASE WHEN order_status = 4 THEN unique_id END)                                     AS completed_orders,
        COUNT(CASE WHEN order_status = 5 AND LOWER(attribution) = 'customer' THEN unique_id END) AS customer_cancelled
    FROM b
    GROUP BY order_month, distance_bucket
)
SELECT
    order_month, distance_bucket,
    total_placed, orders_allocated, completed_orders, customer_cancelled,
    ROUND(orders_allocated / NULLIF(total_placed, 0), 4)                       AS allocated_pct,
    ROUND(completed_orders / NULLIF(total_placed, 0), 4)                       AS ff_pct,
    ROUND(completed_orders / NULLIF(total_placed - customer_cancelled, 0), 4)  AS e_ff_pct
FROM agg
ORDER BY order_month, distance_bucket;
```

---

## 3. Unique FF% (month × category × distance)

```sql
WITH base AS (
    SELECT
        m.unique_id, m.customer_id, m.order_time, m.geo_region_id, m.vehicle_mapping,
        COALESCE(m.order_status, 5) AS order_status,
        m.from_address_long, m.from_address_lat, m.to_address_long, m.to_address_lat,
        LEAD(m.order_time)         OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_order_time,
        LEAD(m.from_address_long)  OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_pickup_long,
        LEAD(m.from_address_lat)   OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_pickup_lat,
        LEAD(m.to_address_long)    OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_drop_long,
        LEAD(m.to_address_lat)     OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_drop_lat
    FROM prod_eldoria.mart.hcv_overall_demand_mart m
    JOIN prod_eldoria.core.dim_geo_regions g ON m.geo_region_id = g.geo_region_id
    WHERE COALESCE(m.order_status, 5) IN (4, 5)
      AND m.customer_mobile <> '0000000001'
      AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND m.order_time >= DATE '2026-05-01'
      AND m.order_time <  DATE '2026-08-02'   -- buffer for late-July next-order
),
flagged AS (
    SELECT *,
        ST_DISTANCE(ST_MAKEPOINT(from_address_long, from_address_lat),
                    ST_MAKEPOINT(next_pickup_long, next_pickup_lat)) AS pickup_location_delta,
        ST_DISTANCE(ST_MAKEPOINT(to_address_long, to_address_lat),
                    ST_MAKEPOINT(next_drop_long, next_drop_lat))     AS drop_location_delta,
        DATEDIFF(minute, order_time, next_order_time)                AS ordertime_delta
    FROM base
),
enriched AS (
    SELECT *,
        CASE WHEN pickup_location_delta <= 100 AND drop_location_delta <= 100
              AND ordertime_delta <= 60 AND order_status = 5
             THEN 1 ELSE 0 END AS duplicate_order
    FROM flagged
),
cat AS (
    SELECT
        DATE_TRUNC('month', e.order_time)::date AS order_month,
        e.vehicle_mapping AS category, e.unique_id, e.order_status, e.duplicate_order,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM enriched e
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON e.unique_id = mb.unique_id
    WHERE e.order_time >= DATE '2026-05-01' AND e.order_time < DATE '2026-08-01'
    UNION ALL
    SELECT
        DATE_TRUNC('month', e.order_time)::date,
        CASE WHEN e.geo_region_id = 2 THEN '10ft - NCR' ELSE '10ft - non NCR' END,
        e.unique_id, e.order_status, e.duplicate_order,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM enriched e
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON e.unique_id = mb.unique_id
    WHERE e.vehicle_mapping = '10ft'
      AND e.order_time >= DATE '2026-05-01' AND e.order_time < DATE '2026-08-01'
)
SELECT
    order_month, category, distance_bucket,
    COUNT(CASE WHEN duplicate_order = 0 THEN unique_id END)       AS unique_demand,
    COUNT(DISTINCT CASE WHEN order_status = 4 THEN unique_id END) AS completed_orders,
    ROUND(COUNT(DISTINCT CASE WHEN order_status = 4 THEN unique_id END)
          / NULLIF(COUNT(CASE WHEN duplicate_order = 0 THEN unique_id END), 0), 4) AS unique_ff_pct
FROM cat
GROUP BY order_month, category, distance_bucket
ORDER BY order_month, category, distance_bucket;
```

---

## 3a. Unique FF% (month × distance, overall — no category)

```sql
WITH base AS (
    SELECT
        m.unique_id, m.customer_id, m.order_time,
        COALESCE(m.order_status, 5) AS order_status,
        m.from_address_long, m.from_address_lat, m.to_address_long, m.to_address_lat,
        LEAD(m.order_time)         OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_order_time,
        LEAD(m.from_address_long)  OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_pickup_long,
        LEAD(m.from_address_lat)   OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_pickup_lat,
        LEAD(m.to_address_long)    OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_drop_long,
        LEAD(m.to_address_lat)     OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_drop_lat
    FROM prod_eldoria.mart.hcv_overall_demand_mart m
    JOIN prod_eldoria.core.dim_geo_regions g ON m.geo_region_id = g.geo_region_id
    WHERE COALESCE(m.order_status, 5) IN (4, 5)
      AND m.customer_mobile <> '0000000001'
      AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND m.order_time >= DATE '2026-05-01'
      AND m.order_time <  DATE '2026-08-02'   -- buffer for late-July next-order
),
flagged AS (
    SELECT *,
        ST_DISTANCE(ST_MAKEPOINT(from_address_long, from_address_lat),
                    ST_MAKEPOINT(next_pickup_long, next_pickup_lat)) AS pickup_location_delta,
        ST_DISTANCE(ST_MAKEPOINT(to_address_long, to_address_lat),
                    ST_MAKEPOINT(next_drop_long, next_drop_lat))     AS drop_location_delta,
        DATEDIFF(minute, order_time, next_order_time)                AS ordertime_delta
    FROM base
),
enriched AS (
    SELECT *,
        CASE WHEN pickup_location_delta <= 100 AND drop_location_delta <= 100
              AND ordertime_delta <= 60 AND order_status = 5
             THEN 1 ELSE 0 END AS duplicate_order
    FROM flagged
),
final_rows AS (
    SELECT
        DATE_TRUNC('month', e.order_time)::date AS order_month,
        e.unique_id, e.order_status, e.duplicate_order,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM enriched e
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON e.unique_id = mb.unique_id
    WHERE e.order_time >= DATE '2026-05-01' AND e.order_time < DATE '2026-08-01'
)
SELECT
    order_month, distance_bucket,
    COUNT(CASE WHEN duplicate_order = 0 THEN unique_id END)       AS unique_demand,
    COUNT(DISTINCT CASE WHEN order_status = 4 THEN unique_id END) AS completed_orders,
    ROUND(COUNT(DISTINCT CASE WHEN order_status = 4 THEN unique_id END)
          / NULLIF(COUNT(CASE WHEN duplicate_order = 0 THEN unique_id END), 0), 4) AS unique_ff_pct
FROM final_rows
GROUP BY order_month, distance_bucket
ORDER BY order_month, distance_bucket;
```

---

## 4. Time to accept P50/P75/P90 (month × category × distance)

Time to accept (sec) = `order_time` (IST) → `fo_trip_accepted_time` (UTC epoch sec, converted to IST). Category here uses NCR / non-NCR for 10ft (no overall 10ft row).

```sql
WITH base AS (
    SELECT
        DATE_TRUNC('month', m.order_time)::date AS order_month,
        CASE
            WHEN m.vehicle_mapping = '10ft' AND m.geo_region_id = 2 THEN '10ft - NCR'
            WHEN m.vehicle_mapping = '10ft'                         THEN '10ft - non NCR'
            ELSE m.vehicle_mapping
        END AS category,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket,
        DATEDIFF(
            second,
            m.order_time,
            CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP_NTZ(m.fo_trip_accepted_time))
        ) AS time_to_accept_sec
    FROM prod_eldoria.mart.hcv_overall_demand_mart m
    JOIN prod_eldoria.core.dim_geo_regions g ON m.geo_region_id = g.geo_region_id
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON m.unique_id = mb.unique_id
    WHERE m.customer_mobile <> '0000000001'
      AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND m.fo_trip_accepted_time IS NOT NULL
      AND m.fo_trip_accepted_time > 0
      AND m.order_time >= DATE '2026-05-01'
      AND m.order_time <  DATE '2026-08-01'
)
SELECT
    order_month, category, distance_bucket,
    COUNT(*) AS n_orders,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY time_to_accept_sec) AS p50_sec,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY time_to_accept_sec) AS p75_sec,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY time_to_accept_sec) AS p90_sec
FROM base
WHERE time_to_accept_sec BETWEEN 0 AND 3600   -- drop garbage/negatives
GROUP BY order_month, category, distance_bucket
ORDER BY order_month, category, distance_bucket;
```

---

## 5. Monthly Active Partners (MAP) — Tier 1, 9–19ft

A partner is active in a month if they had ≥1 day with >0.5 business login hours (same threshold as DAP). No distance split (partner-side metric).

```sql
SELECT
    date_trunc('month', login_date)::date AS month,
    COUNT(DISTINCT driver_id)             AS monthly_active_partners
FROM (
    SELECT
        l.day AS login_date,
        l.driver_id
    FROM prod_eldoria.core.fact_active_partners l
    JOIN prod_eldoria.core.dim_vehicles    v ON l.vehicle_id    = v.vehicle_id
    JOIN prod_eldoria.core.dim_geo_regions g ON l.geo_region_id = g.geo_region_id
    WHERE l.day >= '2026-05-01'
      AND l.day <= '2026-07-31'
      AND v.level0_mapping = 'HCV'
      AND g.tier = 'Tier 1'
      AND v.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
    GROUP BY l.day, l.driver_id, g.geo_region_id
    HAVING SUM(l.business_login_hours) > 0.5
)
GROUP BY 1
ORDER BY 1;
```

---

## 6. Combined card — Allocation% / FF% / Unique-FF% as columns (month × category × distance)

One flat table: rows are `order_month`, `category`, `distance_bucket`; the three metrics are columns. Manage the pivot/layout in Metabase. All standard filters kept (Tier 1, 9–19ft, May–Jul, distance from `mbr_mapping_v2`, `fo_driver_id` for allocation).

```sql
WITH base AS (
    SELECT
        m.unique_id, m.customer_id, m.order_time, m.geo_region_id, m.vehicle_mapping, m.fo_driver_id,
        COALESCE(m.order_status, 5) AS order_status,
        m.from_address_long, m.from_address_lat, m.to_address_long, m.to_address_lat,
        LEAD(m.order_time)         OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_order_time,
        LEAD(m.from_address_long)  OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_pickup_long,
        LEAD(m.from_address_lat)   OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_pickup_lat,
        LEAD(m.to_address_long)    OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_drop_long,
        LEAD(m.to_address_lat)     OVER (PARTITION BY m.customer_id ORDER BY m.order_time) AS next_drop_lat
    FROM prod_eldoria.mart.hcv_overall_demand_mart m
    JOIN prod_eldoria.core.dim_geo_regions g ON m.geo_region_id = g.geo_region_id
    WHERE COALESCE(m.order_status, 5) IN (4, 5)
      AND m.customer_mobile <> '0000000001'
      AND m.vehicle_mapping IN ('9ft','10ft','14ft','17ft','19ft')
      AND UPPER(g.tier) = 'TIER 1'
      AND m.order_time >= DATE '2026-05-01'
      AND m.order_time <  DATE '2026-08-02'   -- buffer for late-July next-order
),
flagged AS (
    SELECT *,
        ST_DISTANCE(ST_MAKEPOINT(from_address_long, from_address_lat),
                    ST_MAKEPOINT(next_pickup_long, next_pickup_lat)) AS pickup_location_delta,
        ST_DISTANCE(ST_MAKEPOINT(to_address_long, to_address_lat),
                    ST_MAKEPOINT(next_drop_long, next_drop_lat))     AS drop_location_delta,
        DATEDIFF(minute, order_time, next_order_time)                AS ordertime_delta
    FROM base
),
enriched AS (
    SELECT *,
        CASE WHEN pickup_location_delta <= 100 AND drop_location_delta <= 100
              AND ordertime_delta <= 60 AND order_status = 5 THEN 1 ELSE 0 END AS duplicate_order
    FROM flagged
),
cat AS (
    SELECT
        DATE_TRUNC('month', e.order_time)::date AS order_month,
        e.vehicle_mapping AS category, e.unique_id, e.fo_driver_id, e.order_status, e.duplicate_order,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM enriched e
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON e.unique_id = mb.unique_id
    WHERE e.order_time >= DATE '2026-05-01' AND e.order_time < DATE '2026-08-01'
    UNION ALL
    SELECT
        DATE_TRUNC('month', e.order_time)::date,
        CASE WHEN e.geo_region_id = 2 THEN '10ft - NCR' ELSE '10ft - non NCR' END,
        e.unique_id, e.fo_driver_id, e.order_status, e.duplicate_order,
        CASE WHEN mb.est_distance_km <  100 THEN '<100km'
             WHEN mb.est_distance_km >= 100 THEN '>=100km'
             ELSE 'unknown' END AS distance_bucket
    FROM enriched e
    LEFT JOIN dev_eldoria.sandbox.mbr_mapping_v2 mb ON e.unique_id = mb.unique_id
    WHERE e.vehicle_mapping = '10ft'
      AND e.order_time >= DATE '2026-05-01' AND e.order_time < DATE '2026-08-01'
),
agg AS (
    SELECT order_month, category, distance_bucket,
        COUNT(unique_id)                                            AS total_placed,
        COUNT(CASE WHEN fo_driver_id IS NOT NULL THEN unique_id END) AS allocated,
        COUNT(CASE WHEN order_status = 4 THEN unique_id END)         AS completed,
        COUNT(CASE WHEN duplicate_order = 0 THEN unique_id END)      AS unique_demand
    FROM cat
    GROUP BY order_month, category, distance_bucket
)
SELECT
    order_month,
    category,
    distance_bucket,
    ROUND(allocated  / NULLIF(total_placed, 0),  4) AS allocation_pct,
    ROUND(completed  / NULLIF(total_placed, 0),  4) AS ff_pct,
    ROUND(completed  / NULLIF(unique_demand, 0), 4) AS unique_ff_pct
FROM agg
ORDER BY category, order_month, distance_bucket;
```

---

### Notes & caveats
- Run **section 0 first**; sections 1–4 depend on `mbr_mapping_v2`.
- `unknown` distance bucket = orders with no estimated distance in either `fact_order_fares` or `fact_quotations`. Add `AND est_distance_km IS NOT NULL` if you want to drop them.
- Distance boundary: exactly 100km falls in `>=100km`.
- July 2026 is a partial month (data current as of early July).
- Revenue is OMS-only; validated to match the OMS+SO canonical logic to the rupee for May–Jul (SO branch added only ~18 zero-revenue orders in Jul).
- Allocation uses `fo_driver_id`.
