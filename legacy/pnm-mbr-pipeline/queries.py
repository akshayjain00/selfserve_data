"""
PnM MBR Metrics Automation — SQL Query Definitions
===================================================
All SQL is parameterized with :month_start and :month_start_prev (YYYY-MM-DD strings).

Methodology source: Metabase card #30311  +  Notion MoM doc
https://app.notion.com/p/3599c6eaaa6d8016b554fc2e8e3bf577

Scope: intra_city = TRUE, user_flag = 'normal', exclude Nano where noted.
Source mapping:
    App             source IN (1, 2, 3)
    Desktop Website source_details = 'Desktop Website'
    Mobile Website  source_details = 'Mobile Website'
    Others          source = 4

Staging tables land in PROD_CURATED.NEW_INITIATIVE_ANALYTICS and are
CREATE OR REPLACE'd on every run — safe to re-run without side effects.
"""

from config import TABLES as T, STAGING_SCHEMA

STG = STAGING_SCHEMA   # PROD_CURATED.NEW_INITIATIVE_ANALYTICS


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1 — STAGING TABLES
# Written to PROD_CURATED.NEW_INITIATIVE_ANALYTICS once per run.
# All downstream metric queries SELECT from these tables.
# ═══════════════════════════════════════════════════════════════════════════════

CREATE_STG_LEADS = f"""
CREATE OR REPLACE TABLE {STG}.pnm_mbr_leads AS
SELECT
    f.opp_id,
    f.opp_created_ts,
    f.source,
    f.source_details,
    f.sr_id,
    d.intra_city,
    d.user_flag,
    d.is_nano
FROM {T['fact_opp']} f
JOIN {T['dim_opp']}  d USING (opp_id)
WHERE DATE_TRUNC('month', f.opp_created_ts) IN (:month_start, :month_start_prev)
  AND d.intra_city = TRUE
  AND d.user_flag  = 'normal'
"""

CREATE_STG_ORDERS = f"""
CREATE OR REPLACE TABLE {STG}.pnm_mbr_orders AS
WITH raw_orders AS (
    SELECT
        o.order_id,
        o.sr_id,
        o.o_created_ts,
        o.o_completed_ts,
        o.status,
        d.intra_city,
        d.user_flag,
        d.is_nano,
        l.source,
        l.source_details,
        o.vendor_accepted_ts,
        o.supervisor_assigned_ts,
        o.supervisor_accepted_ts,
        o.trip_started_ts,
        o.shifting_started_ts,
        o.pickup_completed_ts,
        o.order_completed_ts
    FROM {T['orders']} o
    INNER JOIN {T['pnm_customers']}  c ON o.customer_id = c.customer_id
    LEFT  JOIN {T['dim_orders']}     d USING (order_id)
    LEFT  JOIN {STG}.pnm_mbr_leads   l ON o.sr_id = l.sr_id
    WHERE DATE_TRUNC('month', o.o_created_ts) IN (:month_start, :month_start_prev)
      AND d.intra_city = TRUE
      AND d.user_flag  = 'normal'
      AND o.status    != 4
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.sr_id ORDER BY o.o_created_ts) = 1
)
SELECT * FROM raw_orders
"""


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2 — LEADS
# ═══════════════════════════════════════════════════════════════════════════════

QUERY_LEADS = f"""
SELECT
    DATE_TRUNC('month', opp_created_ts)                                          AS month,
    COUNT(DISTINCT opp_id)                                                       AS leads_overall,
    COUNT(DISTINCT CASE WHEN source IN (1,2,3)                  THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN source_details = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN source_details = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN source = 4                         THEN opp_id END) AS leads_others
FROM {STG}.pnm_mbr_leads
GROUP BY 1
ORDER BY 1
"""


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3 — BOOKED ORDERS
# ═══════════════════════════════════════════════════════════════════════════════

QUERY_ORDERS = f"""
SELECT
    DATE_TRUNC('month', o_created_ts)                                                AS month,
    COUNT(DISTINCT order_id)                                                         AS orders_overall,
    COUNT(DISTINCT CASE WHEN source IN (1,2,3)                  THEN order_id END)  AS orders_app,
    COUNT(DISTINCT CASE WHEN source_details = 'Desktop Website' THEN order_id END)  AS orders_desktop,
    COUNT(DISTINCT CASE WHEN source_details = 'Mobile Website'  THEN order_id END)  AS orders_mobile,
    COUNT(DISTINCT CASE WHEN source = 4                         THEN order_id END)  AS orders_others
FROM {STG}.pnm_mbr_orders
GROUP BY 1
ORDER BY 1
"""


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4 — CONVERSION & ORDER MIX
# Derived in Python after fetching leads + orders rows.
# See runner.py: _compute_derived_metrics()
# ═══════════════════════════════════════════════════════════════════════════════


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5 — OTA %
# Completed intra-city non-Nano orders. Month = o_completed_ts.
# OTA = arrived ≤30 min late AND ≤2 km from scheduled pickup location.
# ⚠ VERIFY: scheduled_pickup_ts, vendor_arrived_ts, coordinate column names.
# ═══════════════════════════════════════════════════════════════════════════════

QUERY_OTA = f"""
WITH completed AS (
    SELECT
        order_id,
        o_completed_ts,
        DATEDIFF('minute', scheduled_pickup_ts, vendor_arrived_ts)   AS delay_mins,
        ST_DISTANCE(
            ST_MAKEPOINT(scheduled_pickup_lon, scheduled_pickup_lat),
            ST_MAKEPOINT(actual_arrival_lon,   actual_arrival_lat)
        ) / 1000.0                                                    AS deviation_km
    FROM {STG}.pnm_mbr_orders
    WHERE status  = 2
      AND is_nano = FALSE
      AND o_completed_ts IS NOT NULL
)
SELECT
    DATE_TRUNC('month', o_completed_ts)                                      AS month,
    COUNT(*)                                                                   AS base_orders,
    ROUND(100.0 * COUNT(CASE WHEN delay_mins <= 30
                              AND deviation_km <= 2 THEN 1 END)
                / NULLIF(COUNT(*), 0), 2)                                      AS ota_pct,
    ROUND(100.0 * COUNT(CASE WHEN delay_mins > 60 THEN 1 END)
                / NULLIF(COUNT(*), 0), 4)                                      AS delay_over_60_mins_pct
FROM completed
GROUP BY 1
ORDER BY 1
"""


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6 — P80 DURATION MILESTONES  (minutes)
# Non-Nano, intra-city, completed orders.
# ═══════════════════════════════════════════════════════════════════════════════

QUERY_P80_DURATIONS = f"""
SELECT
    DATE_TRUNC('month', o_completed_ts)                                         AS month,

    PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY DATEDIFF('minute', shifting_started_ts, order_completed_ts)
    ) AS p80_trip_duration_mins,

    PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY DATEDIFF('minute', vendor_accepted_ts, supervisor_assigned_ts)
    ) AS p80_vendor_accept_to_sup_assign_mins,

    PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY DATEDIFF('minute', supervisor_assigned_ts, trip_started_ts)
    ) AS p80_sup_assign_to_trip_start_mins,

    PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY DATEDIFF('minute', trip_started_ts, shifting_started_ts)
    ) AS p80_trip_start_to_shifting_start_mins,

    PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY DATEDIFF('minute', shifting_started_ts, pickup_completed_ts)
    ) AS p80_shifting_start_to_pickup_complete_mins,

    PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY DATEDIFF('minute', pickup_completed_ts, order_completed_ts)
    ) AS p80_pickup_complete_to_order_complete_mins

FROM {STG}.pnm_mbr_orders
WHERE status  = 2
  AND is_nano = FALSE
  AND shifting_started_ts IS NOT NULL
  AND order_completed_ts  IS NOT NULL
GROUP BY 1
ORDER BY 1
"""


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7 — TPO (Tickets Per Order)
# Denominator: all non-Nano intra-city orders. Month = allocation completion date.
# ⚠ VERIFY: tickets table name, raised_by / order_status_at_creation column names.
# ═══════════════════════════════════════════════════════════════════════════════

QUERY_TPO = f"""
WITH order_base AS (
    SELECT
        o.order_id,
        DATE_TRUNC('month', a.completed_ts) AS alloc_month
    FROM {STG}.pnm_mbr_orders o
    JOIN {T['order_alloc']} a ON o.order_id = a.order_id
    WHERE o.is_nano = FALSE
      AND a.completed_ts IS NOT NULL
),
ticket_data AS (
    SELECT t.order_id, t.created_at, t.raised_by, t.order_status_at_creation
    FROM {T['tickets']} t
    JOIN order_base b ON t.order_id = b.order_id
    WHERE LOWER(t.raised_by) NOT LIKE '%detractor%'
),
monthly AS (
    SELECT
        b.alloc_month                                                                   AS month,
        COUNT(DISTINCT b.order_id)                                                     AS orders_base,
        COUNT(t.order_id)                                                              AS tickets_overall,
        COUNT(CASE WHEN t.raised_by IN ('Vendor-Owner','Vendor-Supervisor') THEN 1 END) AS tickets_vendor,
        COUNT(CASE WHEN t.order_status_at_creation IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                   THEN 1 END)                                                         AS tickets_pre_trip,
        COUNT(CASE WHEN t.order_status_at_creation IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                        AND t.raised_by = 'Customer' THEN 1 END)                      AS tickets_pre_trip_cust,
        COUNT(CASE WHEN t.order_status_at_creation IN ('trip_started','shifting_started')
                   THEN 1 END)                                                         AS tickets_trip_shift,
        COUNT(CASE WHEN t.order_status_at_creation IN ('trip_started','shifting_started')
                        AND t.raised_by = 'Customer' THEN 1 END)                      AS tickets_trip_shift_cust,
        COUNT(CASE WHEN t.order_status_at_creation = 'pickup_completed' THEN 1 END)   AS tickets_pickup,
        COUNT(CASE WHEN t.order_status_at_creation = 'pickup_completed'
                        AND t.raised_by = 'Customer' THEN 1 END)                      AS tickets_pickup_cust,
        COUNT(CASE WHEN t.order_status_at_creation = 'completed' THEN 1 END)          AS tickets_completed,
        COUNT(CASE WHEN t.order_status_at_creation = 'completed'
                        AND t.raised_by = 'Customer' THEN 1 END)                      AS tickets_completed_cust,
        COUNT(CASE WHEN t.order_status_at_creation = 'cancelled' THEN 1 END)          AS tickets_cancelled,
        COUNT(CASE WHEN t.order_status_at_creation = 'cancelled'
                        AND t.raised_by = 'Customer' THEN 1 END)                      AS tickets_cancelled_cust
    FROM order_base b
    LEFT JOIN ticket_data t ON b.order_id = t.order_id
                             AND DATE_TRUNC('month', t.created_at) = b.alloc_month
    GROUP BY 1
)
SELECT
    month,
    orders_base,
    ROUND(tickets_overall        / NULLIF(orders_base,0), 4) AS tpo_overall,
    ROUND(tickets_vendor         / NULLIF(orders_base,0), 4) AS tpo_vendor_raised,
    ROUND(tickets_pre_trip       / NULLIF(orders_base,0), 4) AS tpo_pre_trip,
    ROUND(tickets_pre_trip_cust  / NULLIF(orders_base,0), 4) AS tpo_pre_trip_customer,
    ROUND(tickets_trip_shift     / NULLIF(orders_base,0), 4) AS tpo_trip_shift,
    ROUND(tickets_trip_shift_cust/ NULLIF(orders_base,0), 4) AS tpo_trip_shift_customer,
    ROUND(tickets_pickup         / NULLIF(orders_base,0), 4) AS tpo_pickup,
    ROUND(tickets_pickup_cust    / NULLIF(orders_base,0), 4) AS tpo_pickup_customer,
    ROUND(tickets_completed      / NULLIF(orders_base,0), 4) AS tpo_completed,
    ROUND(tickets_completed_cust / NULLIF(orders_base,0), 4) AS tpo_completed_customer,
    ROUND(tickets_cancelled      / NULLIF(orders_base,0), 4) AS tpo_cancelled,
    ROUND(tickets_cancelled_cust / NULLIF(orders_base,0), 4) AS tpo_cancelled_customer
FROM monthly
ORDER BY 1
"""


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8 — ORDER EDITS
# Denominator: completed non-Nano intra-city orders. Month = o_created_ts.
# ⚠ VERIFY: order_modifications table name; category / source / order_phase columns.
# ═══════════════════════════════════════════════════════════════════════════════

QUERY_ORDER_EDITS = f"""
WITH edit_base AS (
    SELECT order_id, o_created_ts
    FROM {STG}.pnm_mbr_orders
    WHERE status  = 2
      AND is_nano = FALSE
),
mods AS (
    SELECT m.order_id, m.category, m.source, m.order_phase
    FROM {T['order_mods']} m
    JOIN edit_base b ON m.order_id = b.order_id
    WHERE m.category IN ('Locations','ShiftingTime','Items','AddOns')
),
agg AS (
    SELECT
        DATE_TRUNC('month', b.o_created_ts)                                        AS month,
        COUNT(DISTINCT b.order_id)                                                  AS total_orders,
        COUNT(DISTINCT CASE WHEN m.order_id IS NOT NULL THEN b.order_id END)        AS orders_with_any_edit,
        COUNT(m.order_id)                                                           AS total_edit_events,
        COUNT(DISTINCT CASE WHEN m.source NOT IN ('customer_app_webview','customer')
                            THEN b.order_id END)                                    AS orders_support_edited,
        COUNT(DISTINCT CASE WHEN m.category = 'Locations'    THEN b.order_id END)  AS orders_edit_location,
        COUNT(DISTINCT CASE WHEN m.category = 'Items'        THEN b.order_id END)  AS orders_edit_items,
        COUNT(DISTINCT CASE WHEN m.category = 'AddOns'       THEN b.order_id END)  AS orders_edit_addons,
        COUNT(DISTINCT CASE WHEN m.category = 'ShiftingTime' THEN b.order_id END)  AS orders_edit_slot,
        COUNT(CASE WHEN m.order_phase IN ('after_shifting_started','after_pickup_completed')
                   THEN 1 END)                                                      AS edits_after_shifting
    FROM edit_base b
    LEFT JOIN mods m USING (order_id)
    GROUP BY 1
)
SELECT
    month,
    total_orders,
    ROUND(100.0 * orders_with_any_edit  / NULLIF(total_orders,0), 2)       AS pct_orders_edited,
    total_edit_events                                                        AS num_successful_edits,
    ROUND(100.0 * orders_support_edited / NULLIF(total_orders,0), 2)       AS pct_support_edited_orders,
    ROUND(100.0 * orders_edit_location  / NULLIF(total_orders,0), 2)       AS pct_edit_location_adoption,
    ROUND(100.0 * orders_edit_items     / NULLIF(total_orders,0), 2)       AS pct_edit_items_adoption,
    ROUND(100.0 * orders_edit_addons    / NULLIF(total_orders,0), 2)       AS pct_edit_addons_adoption,
    ROUND(100.0 * orders_edit_slot      / NULLIF(total_orders,0), 2)       AS pct_edit_slot_adoption,
    ROUND(total_edit_events::FLOAT      / NULLIF(total_orders,0), 2)       AS edits_per_order,
    ROUND(100.0 * edits_after_shifting  / NULLIF(total_edit_events,0), 2)  AS pct_edits_after_shifting
FROM agg
ORDER BY 1
"""


# ═══════════════════════════════════════════════════════════════════════════════
# Registry — maps section name → query + output columns
# ═══════════════════════════════════════════════════════════════════════════════

METRIC_SECTIONS = [
    {
        "name":    "leads",
        "query":   QUERY_LEADS,
        "columns": ["leads_overall","leads_app","leads_desktop","leads_mobile","leads_others"],
    },
    {
        "name":    "orders",
        "query":   QUERY_ORDERS,
        "columns": ["orders_overall","orders_app","orders_desktop","orders_mobile","orders_others"],
    },
    {
        "name":    "ota",
        "query":   QUERY_OTA,
        "columns": ["base_orders","ota_pct","delay_over_60_mins_pct"],
    },
    {
        "name":    "p80_durations",
        "query":   QUERY_P80_DURATIONS,
        "columns": [
            "p80_trip_duration_mins",
            "p80_vendor_accept_to_sup_assign_mins",
            "p80_sup_assign_to_trip_start_mins",
            "p80_trip_start_to_shifting_start_mins",
            "p80_shifting_start_to_pickup_complete_mins",
            "p80_pickup_complete_to_order_complete_mins",
        ],
    },
    {
        "name":    "tpo",
        "query":   QUERY_TPO,
        "columns": [
            "orders_base","tpo_overall","tpo_vendor_raised",
            "tpo_pre_trip","tpo_pre_trip_customer",
            "tpo_trip_shift","tpo_trip_shift_customer",
            "tpo_pickup","tpo_pickup_customer",
            "tpo_completed","tpo_completed_customer",
            "tpo_cancelled","tpo_cancelled_customer",
        ],
    },
    {
        "name":    "order_edits",
        "query":   QUERY_ORDER_EDITS,
        "columns": [
            "total_orders","pct_orders_edited","num_successful_edits",
            "pct_support_edited_orders",
            "pct_edit_location_adoption","pct_edit_items_adoption",
            "pct_edit_addons_adoption","pct_edit_slot_adoption",
            "edits_per_order","pct_edits_after_shifting",
        ],
    },
]
