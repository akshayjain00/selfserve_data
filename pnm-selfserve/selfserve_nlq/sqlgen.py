"""
PnM Self-Serve NL Query Layer — Deterministic SQL generation (v0)
=================================================================
One read-only SELECT per section. As of 2026-07-08 the section SQL MIRRORS the
owner's live-validated MBR automation (pnm/pnm_mbr_monthly_metrics/queries.py):

  * leads / orders / derived  ->  LEADS_CONVERSION_QUERY (validated 2026-07-08
    against PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY / DIM_PNM_OPPORTUNITY /
    FACT_PNM_ORDERS / DIM_PNM_ORDERS and PROD_ELDORIA.MART.PNM_CUSTOMERS)
  * tpo                       ->  TPO_TREND_QUERY / card #47576 (validated
    2026-07-07 against PROD_CURATED.PNM_APPLICATION.ORDERS / ORDER_ALLOCATION_INFOS
    / SHIFTING_REQUIREMENTS and PROD_CURATED.SFMS_PUBLIC.HS_TICKETS)

This supersedes the earlier "bug-for-bug replicate the 5-file staging pipeline
on raw pnm_application tables" approach (owner decision A, 2026-07-08 — see
ORDERS_SOURCE_DECISION in metrics_registry): the configured raw tables never
carried the needed columns, so we adopt the governed, already-validated queries.

Adaptations vs. the automation's queries (deliberate, structure-only):
  * the automation runs OPEN-ENDED from a start_date and returns every month;
    this layer answers ONE month, so `DATE(...) >= start_date` becomes
    `DATE_TRUNC('month', ...) = '{month_start}'` (single validated literal).
  * the automation reports channel splits as PERCENTAGES; this layer emits the
    raw per-channel COUNTS and lets the Python derived layer compute the %s and
    conversion (ratios from raw counts, never averaged) — same numbers, and it
    keeps the registry's count-metric ids (leads_app, orders_app, ...).

Business rule baked in (owner, 2026-07-08): NANO = labour-only help (no vehicle),
owned by LA. It is INCLUDED in leads (PnM demand) but EXCLUDED from orders and
TPO (those bookings are attributed to LA, not PnM). Numbers therefore reconcile
against the MBR note / Notion Demand DB, not Metabase card #30311.
"""

import re
from datetime import date

MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


def month_bounds(month: str) -> tuple[str, str]:
    """'2026-05' -> ('2026-05-01', '2026-04-01') = (month_start, month_start_prev).

    The section SQL only uses month_start (single-month answers); month_start_prev
    is retained for API stability / callers that still reference it.
    """
    if not MONTH_RE.match(month):
        raise ValueError(f"month must be YYYY-MM, got {month!r}")
    y, m = int(month[:4]), int(month[5:7])
    py, pm = (y - 1, 12) if m == 1 else (y, m - 1)
    return f"{y:04d}-{m:02d}-01", f"{py:04d}-{pm:02d}-01"


def is_month_in_progress(month: str, today: date | None = None) -> bool:
    today = today or date.today()
    return month == today.strftime("%Y-%m")


def is_month_in_future(month: str, today: date | None = None) -> bool:
    today = today or date.today()
    return month > today.strftime("%Y-%m")


# Channel bucket, mirroring LEADS_CONVERSION_QUERY's CASE verbatim (App / Desktop
# Website / Mobile Website / Others). `d` is the OPPORTUNITY dim alias on both the
# leads side and the orders side (orders inherit channel from their lead via sr_id).
def _channel_case(d: str) -> str:
    return f"""CASE
            WHEN {d}.source_details = 'Desktop Website' THEN 'Desktop Website'
            WHEN {d}.source_details = 'Mobile Website'  THEN 'Mobile Website'
            WHEN {d}.source IN (1, 2, 3)                 THEN 'App'
            WHEN {d}.source = 4                           THEN 'Others'
            ELSE 'Mobile Website'
        END"""


# ── Leads CTE (mirrors LEADS_CONVERSION_QUERY `leads`) ────────────────────────
# Nano INCLUDED (no package filter). intra-city via shifting_type on the dim
# (nulls allowed, per the validated query). Normal users only.
CTE_LEADS = """\
leads_base AS (
    SELECT
        f.opp_id,
        {channel} AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY f
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY d ON d.opp_id = f.opp_id
    WHERE d.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', f.opp_created_ts) = '{month_start}'
      AND (d.shifting_type = 'intra_city' OR d.shifting_type IS NULL)
)"""

# ── Orders CTE (mirrors LEADS_CONVERSION_QUERY `order_with_source`) ───────────
# Orders EXCLUDE nano (attributed to LA). Channel inherited from the order's lead
# (opportunity dim via sr_id). Dedup is per ORDER_ID on the opp-join fan-out.
# NO cancelled filter (counts all orders created in the month). crn must be PnM.
CTE_ORDERS = """\
orders_base_raw AS (
    SELECT
        o.order_id,
        {channel} AS channel
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o
    INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS       pc  ON pc.customer_mobile = o.customer_mobile
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS      dord ON dord.order_id = o.order_id
    LEFT  JOIN PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo ON fpo.sr_id = o.sr_id
    LEFT  JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY  d   ON d.opp_id = fpo.opp_id
    WHERE dord.user_flag ILIKE 'normal'
      AND DATE_TRUNC('month', o.o_created_ts) = '{month_start}'
      AND dord.shifting_type = 'intra_city'
      AND o.crn LIKE '%PNM%'
      AND (dord.package_name NOT ILIKE 'Nano%' OR dord.package_name IS NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.order_id ORDER BY fpo.opp_id DESC NULLS LAST) = 1
)"""

# The `month` column (a validated literal, not GROUP BY) is emitted so ask.py can
# match the single result row by month — uniform with the tpo section.
AGG_LEADS = """\
SELECT
    DATE '{month_start}'                                                AS month,
    COUNT(DISTINCT opp_id)                                              AS leads_overall_intra_city,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN opp_id END) AS leads_others
FROM leads_base"""

AGG_ORDERS = """\
SELECT
    DATE '{month_start}'                                                    AS month,
    COUNT(DISTINCT order_id)                                                AS orders_overall,
    COUNT(DISTINCT CASE WHEN channel = 'App'             THEN order_id END) AS orders_app,
    COUNT(DISTINCT CASE WHEN channel = 'Desktop Website' THEN order_id END) AS orders_desktop,
    COUNT(DISTINCT CASE WHEN channel = 'Mobile Website'  THEN order_id END) AS orders_mobile,
    COUNT(DISTINCT CASE WHEN channel = 'Others'          THEN order_id END) AS orders_others
FROM orders_base_raw"""


def leads_sql(month: str) -> str:
    ms, _ = month_bounds(month)
    cte = CTE_LEADS.format(channel=_channel_case("d"), month_start=ms)
    return f"WITH {cte}\n{AGG_LEADS.format(month_start=ms)}"


def orders_sql(month: str) -> str:
    ms, _ = month_bounds(month)
    cte = CTE_ORDERS.format(channel=_channel_case("d"), month_start=ms)
    return f"WITH {cte}\n{AGG_ORDERS.format(month_start=ms)}"


def funnel_sql(month: str) -> str:
    """Leads + orders per-channel counts on one row — the input for the derived
    metrics (conversion, order-mix), which runner/ask compute in Python from
    these raw counts (never by averaging ratios). Mirrors LEADS_CONVERSION_QUERY
    but emits counts, not the automation's percentages."""
    ms, _ = month_bounds(month)
    leads_cte = CTE_LEADS.format(channel=_channel_case("d"), month_start=ms)
    orders_cte = CTE_ORDERS.format(channel=_channel_case("d"), month_start=ms)
    return f"""WITH {leads_cte},
{orders_cte},
leads_monthly AS (
{AGG_LEADS.format(month_start=ms)}
),
orders_monthly AS (
{AGG_ORDERS.format(month_start=ms)}
)
SELECT
    l.month,
    l.leads_overall_intra_city, l.leads_app, l.leads_desktop, l.leads_mobile, l.leads_others,
    o.orders_overall, o.orders_app, o.orders_desktop, o.orders_mobile, o.orders_others
FROM leads_monthly l
CROSS JOIN orders_monthly o"""


def tpo_sql(month: str) -> str:
    ms, _ = month_bounds(month)
    # Mirrors TPO_TREND_QUERY (card #47576), validated 2026-07-07 against PROD_CURATED.
    # Denominator: distinct PnM crns with an active completed allocation in the month
    # (completed_ts is UTC -> +330m for IST month). Nano EXCLUDED (LA). Tickets joined
    # on crn, non-detractor, non-nano, intra-city; bucketed by order_status_when_ticket_created.
    return f"""WITH orders AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) AS month,
        COUNT(DISTINCT a.crn) AS total_orders
    FROM PROD_CURATED.PNM_APPLICATION.ORDERS a
    JOIN PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS b ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE a.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) = '{ms}'
    GROUP BY 1
),
tickets AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) AS month,
        COUNT(DISTINCT hst.ticket_number) AS tickets_overall,
        COUNT(DISTINCT CASE WHEN hst.raised_by ILIKE 'Vendor%' THEN hst.ticket_number END) AS tickets_vendor,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                   THEN hst.ticket_number END) AS tickets_pre_trip,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pre_trip_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started')
                   THEN hst.ticket_number END) AS tickets_trip_shift,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started')
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_trip_shift_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed'
                   THEN hst.ticket_number END) AS tickets_pickup,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pickup_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed'
                   THEN hst.ticket_number END) AS tickets_completed,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_completed_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled'
                   THEN hst.ticket_number END) AS tickets_cancelled,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_cancelled_cust
    FROM PROD_CURATED.SFMS_PUBLIC.HS_TICKETS hst
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND hst.hs_package NOT ILIKE '%Nano%'
      AND COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) = '{ms}'
    GROUP BY 1
)
SELECT
    o.month,
    o.total_orders                                                       AS orders_base,
    ROUND(t.tickets_overall         / NULLIF(o.total_orders, 0), 4) AS tpo_overall,
    ROUND(t.tickets_vendor          / NULLIF(o.total_orders, 0), 4) AS tpo_vendor_raised,
    ROUND(t.tickets_pre_trip        / NULLIF(o.total_orders, 0), 4) AS tpo_pre_trip,
    ROUND(t.tickets_pre_trip_cust   / NULLIF(o.total_orders, 0), 4) AS tpo_pre_trip_customer,
    ROUND(t.tickets_trip_shift      / NULLIF(o.total_orders, 0), 4) AS tpo_trip_shift,
    ROUND(t.tickets_trip_shift_cust / NULLIF(o.total_orders, 0), 4) AS tpo_trip_shift_customer,
    ROUND(t.tickets_pickup          / NULLIF(o.total_orders, 0), 4) AS tpo_pickup,
    ROUND(t.tickets_pickup_cust     / NULLIF(o.total_orders, 0), 4) AS tpo_pickup_customer,
    ROUND(t.tickets_completed       / NULLIF(o.total_orders, 0), 4) AS tpo_completed,
    ROUND(t.tickets_completed_cust  / NULLIF(o.total_orders, 0), 4) AS tpo_completed_customer,
    ROUND(t.tickets_cancelled       / NULLIF(o.total_orders, 0), 4) AS tpo_cancelled,
    ROUND(t.tickets_cancelled_cust  / NULLIF(o.total_orders, 0), 4) AS tpo_cancelled_customer
FROM orders o
LEFT JOIN tickets t ON t.month = o.month
ORDER BY o.month"""


def p80_sql(month: str) -> str:
    """Mirrors TRIP_DURATION_PERCENTILE_QUERY (owner's live-validated automation),
    single-month. Percentiles of per-order stage durations (minutes) over completed,
    non-Nano, intra-city orders. Month grain = SHIFTING_TS_IST. Both SUPERVISOR_ACCEPTED
    and SUPERVISOR_ASSIGNED columns exist in the mart; the automation deliberately reads
    ACCEPTED for the "supervisor assigned" stages (replicated bug-for-bug). The open-ended
    `>= start_date` becomes a prunable single-month range on the NTZ SHIFTING_TS_IST."""
    ms, _ = month_bounds(month)
    return f"""SELECT
    DATE '{ms}' AS month,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', VENDOR_OWNER_ACCEPTED_TS_IST, SUPERVISOR_ACCEPTED_TS_IST)), 1) AS p80_vendor_accepted_to_sup_assigned,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SUPERVISOR_ACCEPTED_TS_IST, TRIP_STARTED_TS_IST)), 1)           AS p80_sup_assigned_to_trip_started,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', TRIP_STARTED_TS_IST, SHIFTING_STARTED_TS_IST)), 1)              AS p80_trip_started_to_shifting_started,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, PICKUP_COMPLETED_TS_IST)), 1)          AS p80_shifting_started_to_pickup_complete,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', PICKUP_COMPLETED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p80_pickup_complete_to_order_complete,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p50_trip_duration,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF('minute', SHIFTING_STARTED_TS_IST, ORDER_COMPLETED_TS_IST)), 1)           AS p80_trip_duration
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
WHERE SHIFTING_TS_IST >= '{ms}'
  AND SHIFTING_TS_IST <  DATEADD('month', 1, DATE '{ms}')
  AND ORDER_STATUS = 'completed'
  AND PACKAGE_NAME NOT ILIKE 'Nano%'
  AND SHIFTING_TYPE = 'intra_city'"""


def order_edits_sql(month: str) -> str:
    """Mirrors EDIT_ADOPTION_QUERY (owner's live-validated automation), single-month.
    Edit-adoption rates over completed, non-Nano, intra-city orders. Month grain =
    ORDER_CREATED_TS_IST. All %s are computed IN SQL (unlike leads/orders which emit
    counts and derive %s in Python) — so every metric here is source:"sql". #10
    (pct_edits_after_shifting_started) divides by NO_OF_SUCCESSFUL_EDITS; all other %s
    by total_orders. location adoption is emitted under two ids by design."""
    ms, _ = month_bounds(month)
    return f"""WITH base AS (
    SELECT
        COUNT(DISTINCT pe.ORDER_ID)                                                    AS total_orders,
        COUNT(DISTINCT CASE WHEN pe.IS_MODIFICATION_DONE = 'Yes' THEN pe.ORDER_ID END) AS orders_with_mods,
        SUM(pe.NO_OF_SUCCESSFUL_EDITS)                                                 AS no_of_successful_edits,
        SUM(pe.EDITS_AFTER_SHIFTING)                                                   AS edits_after_shifting,
        COUNT(DISTINCT CASE WHEN pe.HAS_SUPPORT_EDIT  = 1 THEN pe.ORDER_ID END)        AS support_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_LOCATION_EDIT = 1 THEN pe.ORDER_ID END)        AS location_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ITEMS_EDIT    = 1 THEN pe.ORDER_ID END)        AS items_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_ADDONS_EDIT   = 1 THEN pe.ORDER_ID END)        AS addons_edited_orders,
        COUNT(DISTINCT CASE WHEN pe.HAS_SLOT_EDIT     = 1 THEN pe.ORDER_ID END)        AS slot_edited_orders
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    WHERE pe.ORDER_CREATED_TS_IST >= '{ms}'
      AND pe.ORDER_CREATED_TS_IST <  DATEADD('month', 1, DATE '{ms}')
      AND pe.ORDER_STATUS = 'completed'
      AND pe.SHIFTING_TYPE = 'intra_city'
      AND pe.PACKAGE_NAME NOT ILIKE 'Nano%'
)
SELECT
    DATE '{ms}' AS month,
    ROUND(100.0 * orders_with_mods       / NULLIF(total_orders, 0), 2)           AS pct_orders_edited,
    no_of_successful_edits,
    ROUND(100.0 * support_edited_orders  / NULLIF(total_orders, 0), 2)           AS pct_support_edited_orders,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS location_adoption_pct,
    ROUND(100.0 * location_edited_orders / NULLIF(total_orders, 0), 2)           AS pct_orders_location_modified,
    ROUND(100.0 * items_edited_orders    / NULLIF(total_orders, 0), 2)           AS items_adoption_pct,
    ROUND(100.0 * addons_edited_orders   / NULLIF(total_orders, 0), 2)           AS addons_adoption_pct,
    ROUND(100.0 * slot_edited_orders     / NULLIF(total_orders, 0), 2)           AS slot_adoption_pct,
    ROUND(no_of_successful_edits * 1.0   / NULLIF(total_orders, 0), 2)           AS edits_per_order,
    ROUND(100.0 * edits_after_shifting   / NULLIF(no_of_successful_edits, 0), 2) AS pct_edits_after_shifting_started
FROM base"""


def ota_sql(month: str) -> str:
    """Mirrors Metabase card #37409 ("On Time Arrival %"), owner-ruled 2026-09-04
    (owner-ruling:2026-09-04): 30 minutes AND 2 km is the correct OTA definition,
    settling PNM-G-024. Anchors on the latest `supervisor_actions` row with
    action='ShiftingStarted' per order (same event PNM_EXPERIENCE.OTA_FLAG and
    pnm_ota_capacity also use) compared to shifting_ts; distance is pickup location
    (SR_LOCATION_DETAILS, location_type=0, latest by id) to that action's GPS.
    Adapted vs. the card: PROD_ELDORIA.RAW in place of the card's DEV_ELDORIA.RAW
    (confirmed byte-identical row counts + max event_ts on 2026-09-04 — an
    environment substitution, not a definition change) and a single-month equality
    filter on o_completed_ts in place of the card's open-ended BETWEEN range."""
    ms, _ = month_bounds(month)
    return f"""WITH orders AS (
    SELECT fpo.order_id, fpo.shifting_ts, fpo.o_completed_ts,
           dpo.package_name, dpo.order_status, dpo.sr_id
    FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS fpo
    LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpo ON dpo.order_id = fpo.order_id
    WHERE DATE_TRUNC('month', fpo.o_completed_ts) = '{ms}'
      AND dpo.shifting_type = 'intra_city'
),
pickup_loc AS (
    SELECT sr_id, location AS pickup_location
    FROM PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS
    WHERE location_type = 0
    QUALIFY ROW_NUMBER() OVER (PARTITION BY sr_id ORDER BY id DESC) = 1
),
ts AS (
    SELECT sa.order_id, sa.event_ts_ist AS event_ts, sa.location AS event_location,
           RANK() OVER (PARTITION BY sa.order_id, sa.action ORDER BY sa.event_ts_ist DESC) AS rk
    FROM PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS sa
    WHERE sa.action = 'ShiftingStarted'
),
dump AS (
    SELECT o.*, pl.pickup_location, ts.event_ts, ts.event_location
    FROM orders o
    LEFT JOIN pickup_loc pl ON o.sr_id = pl.sr_id
    LEFT JOIN ts ON o.order_id = ts.order_id AND ts.rk = 1
),
ota_calc AS (
    SELECT dump.*,
           DATEDIFF(SECONDS, shifting_ts, event_ts) / 60.0 AS delay_minutes,
           CASE
               WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
                    AND event_ts IS NOT NULL
                    AND DATEDIFF(SECONDS, shifting_ts, event_ts) / 60 < 30
                    AND ST_DISTANCE(pickup_location, event_location) / 1000 < 2
               THEN 'On_Time'
               WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
                    AND event_ts IS NULL
               THEN 'Unset'
               ELSE 'Delay'
           END AS group_type
    FROM dump
)
SELECT
    DATE '{ms}' AS month,
    COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               THEN order_id END)                                                            AS ota_total_completed_orders,
    COUNT(DISTINCT CASE WHEN group_type = 'On_Time' THEN order_id END)                        AS ota_on_time_orders,
    COUNT(DISTINCT CASE WHEN group_type = 'Unset'   THEN order_id END)                        AS ota_unset_orders,
    COUNT(DISTINCT CASE WHEN group_type = 'Delay' AND order_status = 'completed'
               AND package_name NOT ILIKE 'Nano%' THEN order_id END)                          AS ota_delay_orders,
    COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               AND delay_minutes >= 60 THEN order_id END)                                     AS ota_delay_gt_60_mins_orders,
    ROUND(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               AND delay_minutes >= 60 THEN order_id END) /
        NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               THEN order_id END), 0), 3)                                                     AS ota_delay_gt_60_mins_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN group_type = 'On_Time' THEN order_id END) /
        NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%'
               THEN order_id END), 0), 2)                                                     AS ota_pct
FROM ota_calc"""


def gac_ctr_sql(month: str) -> str:
    """Mirrors the MBR automation's Get-a-Call CTR section (repo@0deb488:
    reference/mbr_automation_dev_ingestion_v12.sql, PNM-S-060, PNM-G-071). CTR =
    opportunities with a "Get a Call" request ÷ all intra-city opportunities in the
    month. A GAC request is identified via OPPORTUNITIES_LATEST_LSM_SCORE, joined on
    opportunity_id, where opportunity_latest_score = 999 (the automation's own
    sentinel value for "customer requested a callback" — not documented elsewhere,
    taken as given from the automation). Adapted vs. the automation: the open-ended
    `>= start_date` becomes a single-month equality filter (same D7 structure-only
    pattern as every other section); no other change."""
    ms, _ = month_bounds(month)
    return f"""SELECT
    DATE '{ms}' AS month,
    ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN olls.opportunity_id IS NOT NULL THEN opp.id END)
        / NULLIF(COUNT(DISTINCT opp.id), 0),
        2
    ) AS gac_ctr_pct
FROM PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES opp
LEFT JOIN PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES_LATEST_LSM_SCORE olls
    ON opp.id = olls.opportunity_id
    AND olls.opportunity_latest_score = 999
WHERE opp.shifting_type = 'intra_city'
  AND DATE_TRUNC('month', DATE(opp.created_at + INTERVAL '5 hours, 30 minutes')) = '{ms}'"""


def weekend_sql(month: str) -> str:
    """Mirrors the MBR automation's weekend-order-contribution section (PNM-S-060,
    PNM-G-071). DAYOFWEEK(...) IN (0,6) = Sun/Sat, matching the automation's fixed-2026-07-15
    re-source (PNM_EXPERIENCE + FACT_PNM_ORDERS, replacing an older PROD_CURATED version).
    Adapted vs. the automation: single-month equality filter in place of the open-ended
    `>= start_date`; no other change."""
    ms, _ = month_bounds(month)
    return f"""WITH weekend_base AS (
    SELECT
        pe.order_id,
        pe.shifting_ts_ist,
        CASE WHEN DAYOFWEEK(pe.shifting_ts_ist) IN (0,6) THEN 'Weekend' ELSE 'Weekday' END AS day_type
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
    JOIN PROD_ELDORIA.CORE.FACT_PNM_ORDERS fpo ON pe.order_id = fpo.order_id
    WHERE pe.vendor_id IS NOT NULL
      AND fpo.crn ILIKE 'PNM%'
      AND pe.package_name NOT ILIKE 'nano%'
      AND DATE_TRUNC('month', pe.shifting_ts_ist) = '{ms}'
)
SELECT
    DATE '{ms}' AS month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN day_type = 'Weekend' THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS weekend_order_share_pct
FROM weekend_base"""


def cac_post_trip_sql(month: str) -> str:
    """Mirrors the MBR automation's CAC-post-trip-started section (PNM-S-060, PNM-G-071).
    CAC = customer-cancelled after the trip had already started. Adapted vs. the automation:
    single-month equality filter in place of the open-ended `>= start_date`."""
    ms, _ = month_bounds(month)
    return f"""SELECT
    DATE '{ms}' AS month,
    ROUND(
        COUNT(DISTINCT CASE WHEN
            pe.TRIP_STARTED_TS_IST IS NOT NULL
            AND pe.ORDER_STATUS = 'cancelled'
            AND coe.CANCELLED_BY = 'Customer'
        THEN pe.ORDER_ID END) * 100.0
        / NULLIF(COUNT(DISTINCT pe.ORDER_ID), 0),
        2) AS cac_post_trip_started_pct
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE pe
LEFT JOIN PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS coe
    ON coe.order_id = pe.order_id
WHERE pe.SHIFTING_TYPE = 'intra_city'
  AND pe.PACKAGE_NAME NOT ILIKE '%Nano%'
  AND DATE_TRUNC('month', pe.SHIFTING_TS_IST) = '{ms}'"""


def vendor_earnings_pctl_sql(month: str) -> str:
    """Mirrors the MBR automation's vendor-earnings-percentiles section (PNM-S-060,
    PNM-G-071): P50/P80 earnings and orders per active vendor, off PNM_FARE_MOVEMENT.
    Adapted vs. the automation: single-month equality filter in place of the open-ended
    `>= start_date`."""
    ms, _ = month_bounds(month)
    return f"""WITH vendor_metrics AS (
    SELECT vendor_id,
        SUM(vendor_order_fare) AS vendor_total_earnings,
        COUNT(DISTINCT order_id) AS vendor_order_count
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE order_status = 'completed'
      AND is_nano_order = 0
      AND service_type_bucket = 'intracity'
      AND DATE_TRUNC('month', DATE(order_updated_at_ist)) = '{ms}'
    GROUP BY 1
),
period_metrics AS (
    SELECT
        COUNT(DISTINCT order_id) AS total_order_count,
        COUNT(DISTINCT vendor_id) AS active_vendor_count
    FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
    WHERE order_status = 'completed'
      AND is_nano_order = 0
      AND service_type_bucket = 'intracity'
      AND DATE_TRUNC('month', DATE(order_updated_at_ist)) = '{ms}'
)
SELECT
    DATE '{ms}' AS month,
    pm.active_vendor_count,
    pm.total_order_count,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY vm.vendor_total_earnings), 2) AS p50_earnings_per_vendor,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY vm.vendor_total_earnings), 2) AS p80_earnings_per_vendor,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY vm.vendor_order_count), 2) AS p50_orders_per_vendor,
    ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY vm.vendor_order_count), 2) AS p80_orders_per_vendor
FROM vendor_metrics vm
CROSS JOIN period_metrics pm
GROUP BY pm.active_vendor_count, pm.total_order_count"""


def allocation_sql(month: str) -> str:
    """Mirrors the MBR automation's allocation-quality section (PNM-S-060, PNM-G-071),
    the largest single group (33 metrics), off PNM_ALLOCATION. Adapted vs. the automation:
    single-month equality filter (on shifting_ts_ist) in place of the open-ended
    `>= start_date`; no other change — every CASE/threshold copied verbatim."""
    ms, _ = month_bounds(month)
    return f"""SELECT
    DATE '{ms}' AS month,
    COUNT(DISTINCT order_id) AS alloc_total_orders,
    COUNT(DISTINCT CASE WHEN is_allocated = 1 THEN order_id END) AS allocated_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_allocated = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS allocation_pct,
    COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' THEN order_id END) AS total_spot_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_allocated = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' THEN order_id END), 0), 2) AS allocation_pct_spot,
    COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' THEN order_id END) AS total_scheduled_orders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_allocated = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' THEN order_id END), 0), 2) AS allocation_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN allocation_channel = 'Engine' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN allocation_channel IN ('Engine', 'Open Pool') AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS allocation_share_via_engine_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN allocation_channel = 'Open Pool' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN allocation_channel IN ('Engine', 'Open Pool') AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS allocation_share_via_open_pool_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_deallocated_post_accept = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS deallocation_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_deallocated_post_accept = 1 AND order_bucket = 'SPOT' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' THEN order_id END), 0), 2) AS deallocation_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_deallocated_post_accept = 1 AND order_bucket = 'SCHEDULED' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' THEN order_id END), 0), 2) AS deallocation_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS completion_pct,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS completion_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS completion_pct_scheduled,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (
        ORDER BY CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0
            AND dry_run_distance_kms IS NOT NULL THEN dry_run_distance_kms END
    ), 2) AS dry_run_p75_kms_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'CAC' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS cac_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PAC' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS pac_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PoAC' AND order_bucket = 'SPOT'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SPOT' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS poac_pct_spot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'CAC' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS cac_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PAC' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS pac_pct_scheduled,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN cancellation_type = 'PoAC' AND order_bucket = 'SCHEDULED'
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_bucket = 'SCHEDULED' AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS poac_pct_scheduled,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN is_allocated = 1 AND allocation_tat_minutes IS NOT NULL THEN allocation_tat_minutes END
    ), 2) AS allocation_time_p80_minutes,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN is_allocated = 1 AND order_bucket = 'SPOT' AND allocation_tat_minutes IS NOT NULL THEN allocation_tat_minutes END
    ), 2) AS allocation_time_p80_spot_minutes,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN is_allocated = 1 AND allocation_tat_minutes IS NOT NULL
            AND datediff('day', order_created_ts_ist, shifting_ts_ist) <= 2 THEN allocation_tat_minutes END
    ), 2) AS allocation_time_p80_within_2days_minutes,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN no_vendor_before_slot = 1 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_no_vendor_before_slot,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_supervisor_changed = 1 AND order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END), 0), 2) AS pct_supervisor_changed,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_supervisor_changed_post_trip = 1 AND order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed'
        AND package_name NOT IN ('Nano Shifting', 'Nano Shifting Large', 'Nano Shifting Medium') AND is_test_user = 0 THEN order_id END), 0), 2) AS pct_supervisor_changed_post_trip,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN order_status = 'completed' AND is_nano_order = 0 AND is_test_user = 0
            AND pickup_km_deviation IS NOT NULL THEN pickup_km_deviation END
    ), 2) AS p80_pickup_km_deviation,
    ROUND(PERCENTILE_CONT(0.80) WITHIN GROUP (
        ORDER BY CASE WHEN order_status = 'completed' AND is_nano_order = 0 AND is_test_user = 0
            AND drop_km_deviation IS NOT NULL THEN drop_km_deviation END
    ), 2) AS p80_drop_km_deviation,
    COUNT(DISTINCT CASE WHEN deallocation_count > 2 THEN order_id END) AS orders_with_more_than_2_deallocations,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN deallocation_count > 2 THEN order_id END)
        / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_with_more_than_2_deallocations,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN last_rescheduled_shift_ts IS NOT NULL
        AND is_nano_order = 0 AND is_test_user = 0 THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_nano_order = 0 AND is_test_user = 0 THEN order_id END), 0), 2) AS reschedule_pct
FROM PROD_ELDORIA.MART.PNM_ALLOCATION
WHERE DATE_TRUNC('month', shifting_ts_ist) = '{ms}'
  AND shifting_type = 'intra_city'"""


def wallet_sql(month: str) -> str:
    """Mirrors the MBR automation's wallet-withdrawal/recharge section (PNM-S-060,
    PNM-G-071). `vac.VENDOR_ID = v.ID` join is confirmed correct as originally written
    per the automation's own domain-owner note — left unchanged. Adapted vs. the
    automation: single-month equality filter in place of the open-ended `>= start_date`."""
    ms, _ = month_bounds(month)
    return f"""WITH wallet_withdrawals AS (
    SELECT
        ROUND(COUNT(DISTINCT CASE WHEN w.STATUS = 'Failure' THEN w.ID END) * 100.0
            / NULLIF(COUNT(DISTINCT w.ID), 0), 2) AS withdrawal_failure_pct,
        ROUND(COUNT(DISTINCT w.ID) / NULLIF(COUNT(DISTINCT w.VENDOR_OWNER_ID), 0), 2) AS withdrawals_per_vendor,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY w.AMOUNT) AS p50_withdrawal_amount
    FROM PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS v
    JOIN PROD_CURATED.PNM_APPLICATION.VENDOR_WALLET_WITHDRAWAL w
        ON v.ID = w.VENDOR_OWNER_ID
    WHERE v.vendor_id IN (SELECT DISTINCT vendor_id FROM PROD_ELDORIA.CORE.DIM_PNM_VENDOR)
      AND DATE_TRUNC('month', w.CREATED_AT) = '{ms}'
      AND EXISTS (
        SELECT 1
        FROM PROD_CURATED.PNM_APPLICATION.VENDOR_ALLOCATION_CONFIGS vac
        WHERE vac.VENDOR_ID = v.ID
          AND NOT ARRAY_CONTAINS('Labour'::VARIANT, vac.SERVICE_TYPES)
          AND NOT ARRAY_CONTAINS('Helper'::VARIANT, vac.SERVICE_TYPES)
          AND NOT ARRAY_CONTAINS(34::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
          AND NOT ARRAY_CONTAINS(35::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
          AND NOT ARRAY_CONTAINS(36::VARIANT, vac.EXCLUDED_PACKAGE_IDS)
      )
),
wallet_recharges AS (
    SELECT
        ROUND(COUNT(DISTINCT CASE WHEN p.STATUS = 2 THEN p.ID END) * 100.0
            / NULLIF(COUNT(DISTINCT p.ID), 0), 2) AS recharge_failure_pct,
        ROUND(COUNT(DISTINCT p.ID) / NULLIF(COUNT(DISTINCT p.VENDOR_OWNER_ID), 0), 2) AS recharges_per_vendor,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY p.AMOUNT) AS p50_recharge_amount
    FROM PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS v
    JOIN PROD_CURATED.PNM_APPLICATION.PAYMENT_LINKS p
        ON v.ID = p.VENDOR_OWNER_ID
    WHERE p.flow = 'VendorWalletRecharge'
      AND DATE_TRUNC('month', p.created_at) = '{ms}'
)
SELECT
    DATE '{ms}' AS month,
    w.withdrawals_per_vendor, w.p50_withdrawal_amount, w.withdrawal_failure_pct,
    r.recharges_per_vendor, r.p50_recharge_amount, r.recharge_failure_pct
FROM wallet_withdrawals w
CROSS JOIN wallet_recharges r"""


def vendor_tpo_top5_sql(month: str) -> str:
    """Mirrors the MBR automation's vendor-TPO/top-5-issues section (PNM-S-060,
    PNM-G-071) — a pipeline SEPARATE from this catalog's own `tpo` section, reading
    PROD_ELDORIA.RAW.* rather than PROD_CURATED. The issue-breakdown % denominator is
    total_tpo_overall (TPO off ALL tickets), not vendor_tpo — a correction the automation
    itself notes as owner-confirmed 2026-07-06. Adapted vs. the automation: single-month
    equality filter in place of the open-ended `>= start_date`; already emits
    (metric, month, value) directly, no unpivot needed."""
    ms, _ = month_bounds(month)
    return f"""WITH tpo_orders AS (
    SELECT
        DATE_TRUNC('month', DATE(b.completed_ts_ist)) AS period,
        COUNT(DISTINCT a.crn) AS completed_orders
    FROM PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS a
    JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_ORDER_ALLOCATION_INFOS b
        ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS c
        ON a.sr_id = c.id
    WHERE a.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATE(b.completed_ts_ist)) = '{ms}'
    GROUP BY 1
),
tpo_tkt_all AS (
    SELECT
        DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) AS period,
        COUNT(DISTINCT hst.ticket_number) AS tickets
    FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND hst.issue IS NOT NULL
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) = '{ms}'
    GROUP BY 1
),
tpo_tkt_filtered AS (
    SELECT
        DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) AS period,
        hst.issue,
        COUNT(DISTINCT hst.ticket_number) AS tickets
    FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND hst.issue IS NOT NULL
      AND hst.raised_by IN ('Vendor-Owner', 'Vendor-Supervisor')
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATE(hst.created_at + interval '5 hours, 30 minutes')) = '{ms}'
    GROUP BY 1, 2
),
tpo_total_all AS (
    SELECT ta.period, SUM(ta.tickets) / NULLIF(MAX(o.completed_orders), 0) AS total_tpo_overall
    FROM tpo_tkt_all ta JOIN tpo_orders o ON ta.period = o.period
    GROUP BY 1
),
tpo_total_filtered AS (
    SELECT tf.period, SUM(tf.tickets) / NULLIF(MAX(o.completed_orders), 0) AS vendor_tpo
    FROM tpo_tkt_filtered tf JOIN tpo_orders o ON tf.period = o.period
    GROUP BY 1
)
SELECT DATE '{ms}' AS month, 'vendor_tpo' AS metric, ROUND(vendor_tpo, 4) AS value
FROM tpo_total_filtered
UNION ALL
SELECT
    DATE '{ms}' AS month,
    'l1_top5_issues_vendor_raised_' || REPLACE(LOWER(tf.issue), ' ', '_') AS metric,
    ROUND((tf.tickets / NULLIF(o.completed_orders, 0)) / NULLIF(tta.total_tpo_overall, 0) * 100, 2) AS value
FROM tpo_tkt_filtered tf
JOIN tpo_orders o ON tf.period = o.period
JOIN tpo_total_all tta ON tf.period = tta.period
WHERE tf.issue IN (
    'Changes in order requirement', 'Supervisor Reject order', 'Cancellation',
    'Customer Unreachable', 'Payment related'
)"""


def addon_sql(month: str) -> str:
    """Mirrors the MBR automation's add-on-adoption section (PNM-S-060, PNM-G-071).
    ⚠ Deliberately kept WITHOUT ORDER_STATUS='completed' / PACKAGE_NAME NOT ILIKE 'Nano%'
    filters, unlike every other PNM_EXPERIENCE section here — the automation's own owner
    confirms this is intentional (adding those filters raises the overall adoption % from
    ~86-89% to ~97-98%, a real difference). Adapted vs. the automation: single-month
    equality filter in place of the open-ended `>= start_date`."""
    ms, _ = month_bounds(month)
    return f"""SELECT
    DATE '{ms}' AS month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN ADD_ONS IS NOT NULL AND ADD_ONS != '' THEN ORDER_ID END)
        / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_any_addon,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN
        LOWER(ADD_ONS) LIKE '%single-layer packing%' OR LOWER(ADD_ONS) LIKE '%multi-layer packing%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_packing,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN
        LOWER(ADD_ONS) LIKE '%ac installation%' OR LOWER(ADD_ONS) LIKE '%ac uninstallation%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_ac,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN
        LOWER(ADD_ONS) LIKE '%professional carpenter%'
        OR LOWER(ADD_ONS) LIKE '%dismantling and reassembly%'
        OR LOWER(ADD_ONS) LIKE '%dismantelling and reassembly%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_carpentry,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN LOWER(ADD_ONS) LIKE '%rope pull%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_rope_pulling,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN LOWER(ADD_ONS) LIKE '%bigger vehicle%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_bigger_vehicle,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN LOWER(ADD_ONS) LIKE '%extra labour%'
        THEN ORDER_ID END) / NULLIF(COUNT(DISTINCT ORDER_ID), 0), 2) AS pct_orders_with_extra_labour
FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
WHERE SHIFTING_TYPE = 'intra_city'
  AND DATE_TRUNC('month', TO_DATE(ORDER_CREATED_TS_IST)) = '{ms}'"""


def completion_sql(month: str) -> str:
    """Mirrors the MBR automation's completion-score/NPS/detractors section (PNM-S-060,
    PNM-G-071). Adapted vs. the automation: single-month equality filter (on
    shifting_ts_ist) in place of the open-ended `>= start_date`; fixed a trailing-comma
    syntax error present in the automation's own original SQL (owner-confirmed, not a
    definition change)."""
    ms, _ = month_bounds(month)
    return f"""WITH completion_base AS (
    SELECT order_id, vendor_id, order_status, classification
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE package_name NOT ILIKE 'Nano%'
      AND shifting_type = 'intra_city'
      AND DATE_TRUNC('month', shifting_ts_ist) = '{ms}'
)
SELECT
    DATE '{ms}' AS month,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN vendor_id IS NOT NULL THEN order_id END), 0), 2) AS completion_score_pct,
    CASE
        WHEN COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification IS NOT NULL THEN order_id END) > 0
        THEN ROUND(
            100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification = 'Promoter' THEN order_id END)
                  / COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification IS NOT NULL THEN order_id END)
          - 100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification = 'Detractor' THEN order_id END)
                  / COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification IS NOT NULL THEN order_id END), 2)
        ELSE 0
    END AS nps,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND classification = 'Detractor' THEN order_id END)
        / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' THEN order_id END), 0), 2) AS detractor_pct
FROM completion_base"""


def fare_sql(month: str) -> str:
    """Mirrors the MBR automation's fare/coupon/surge section (PNM-S-060, PNM-G-071),
    off PNM_FARE_MOVEMENT. The automation computes this as TWO independently-filtered
    SELECTs unioned by (period, service_type_bucket) then MAX()-aggregated — each half
    populates a different subset of columns and NULLs the rest (order_created_month for
    counts/surge/timing metrics, order_updated_at_ist for AOV/coupon %) — replicated
    verbatim, not simplified, since collapsing to one filter would change which orders
    each metric is computed over. Adapted vs. the automation: single-month equality
    filter in place of the open-ended `>= start_date`."""
    ms, _ = month_bounds(month)
    return f"""WITH fare_metrics AS (
    SELECT
        MAX(total_orders) AS total_orders,
        MAX(aov) AS aov,
        MAX(no_of_orders_with_surge) AS no_of_orders_with_surge,
        MAX(pct_orders_with_surge) AS pct_orders_with_surge,
        MAX(pct_orders_positive_surge) AS pct_orders_positive_surge,
        MAX(pct_orders_negative_surge) AS pct_orders_negative_surge,
        MAX(pct_orders_with_coupon) AS pct_orders_with_coupon,
        MAX(orders_with_shifting_started) AS orders_with_shifting_started,
        MAX(pct_cases_with_price_change_post_shifting_start) AS pct_cases_with_price_change_post_shifting_start,
        MAX(pct_orders_fare_increased) AS pct_orders_fare_increased,
        MAX(median_fare_increase_amt) AS median_fare_increase_amt,
        MAX(pct_orders_fare_decreased) AS pct_orders_fare_decreased,
        MAX(median_fare_decrease_amt) AS median_fare_decrease_amt,
        MAX(pct_edited_orders_with_fare_change) AS pct_edited_orders_with_fare_change
    FROM (
        SELECT
            COUNT(DISTINCT order_id) AS total_orders,
            NULL::FLOAT AS aov,
            COUNT(DISTINCT CASE WHEN booking_surge_multiplier <> 1 AND booking_surge_multiplier IS NOT NULL THEN order_id END) AS no_of_orders_with_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN booking_surge_multiplier <> 1 AND booking_surge_multiplier IS NOT NULL THEN order_id END) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_with_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN booking_surge_multiplier > 1 THEN order_id END) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_positive_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN booking_surge_multiplier < 1 THEN order_id END) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS pct_orders_negative_surge,
            NULL::FLOAT AS pct_orders_with_coupon,
            COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END) AS orders_with_shifting_started,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN fare_delta <> 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END), 0), 2) AS pct_cases_with_price_change_post_shifting_start,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN fare_delta > 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END), 0), 2) AS pct_orders_fare_increased,
            ROUND(MEDIAN(CASE WHEN fare_delta > 0 THEN fare_delta END), 0) AS median_fare_increase_amt,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN fare_delta < 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN shifting_started_ts_ist IS NOT NULL THEN order_id END), 0), 2) AS pct_orders_fare_decreased,
            ROUND(MEDIAN(CASE WHEN fare_delta < 0 THEN ABS(fare_delta) END), 0) AS median_fare_decrease_amt,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN is_edited_post_start = 1 AND fare_delta <> 0 THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN is_edited_post_start = 1 THEN order_id END), 0), 2) AS pct_edited_orders_with_fare_change
        FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
        WHERE order_created_month = '{ms}'
          AND service_type_bucket = 'intracity'

        UNION ALL

        SELECT
            NULL::NUMBER AS total_orders,
            ROUND(SUM(CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%' AND is_test_user = 0 THEN total_order_fare END) / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT ILIKE 'Nano%' AND is_test_user = 0 THEN order_id END), 0), 0) AS aov,
            NULL::NUMBER AS no_of_orders_with_surge,
            NULL::FLOAT AS pct_orders_with_surge,
            NULL::FLOAT AS pct_orders_positive_surge,
            NULL::FLOAT AS pct_orders_negative_surge,
            ROUND(100.0 * COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium') AND discount_coupon IS NOT NULL AND discount_coupon != '' THEN order_id END) / NULLIF(COUNT(DISTINCT CASE WHEN order_status = 'completed' AND package_name NOT IN ('Nano Shifting','Nano Shifting Large','Nano Shifting Medium') THEN order_id END), 0), 2) AS pct_orders_with_coupon,
            NULL::NUMBER AS orders_with_shifting_started,
            NULL::FLOAT AS pct_cases_with_price_change_post_shifting_start,
            NULL::FLOAT AS pct_orders_fare_increased,
            NULL::FLOAT AS median_fare_increase_amt,
            NULL::FLOAT AS pct_orders_fare_decreased,
            NULL::FLOAT AS median_fare_decrease_amt,
            NULL::FLOAT AS pct_edited_orders_with_fare_change
        FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT
        WHERE DATE_TRUNC('month', DATE(order_updated_at_ist)) = '{ms}'
          AND service_type_bucket = 'intracity'
    )
)
SELECT DATE '{ms}' AS month, * FROM fare_metrics"""


def vendor_earnings_bucket_sql(month: str) -> str:
    """Mirrors the MBR automation's vendor-earnings-distribution-by-bucket section
    (PNM-S-060, PNM-G-071): one metric name decomposed into 5, one per vendor bucket
    (GoldPlus/Gold/Silver/Bronze/New), using each vendor's LATEST bucket in the month
    (ROW_NUMBER() by order_completed_ts_ist DESC) applied to ALL of that vendor's orders
    in the month — not each order's own bucket at completion time. Adapted vs. the
    automation: single-month equality filter in place of the open-ended `>= start_date`."""
    ms, _ = month_bounds(month)
    return f"""WITH vendor_earnings_order_base AS (
    SELECT
        order_id, vendor_id,
        COALESCE(vendor_bucket_type, 'New') AS bucket,
        order_completed_ts_ist, total_order_fare
    FROM PROD_ELDORIA.MART.PNM_EXPERIENCE
    WHERE order_status = 'completed'
      AND package_name NOT ILIKE 'Nano%'
      AND shifting_type = 'intra_city'
      AND DATE_TRUNC('month', order_completed_ts_ist) = '{ms}'
),
vendor_earnings_period_bucket AS (
    SELECT vendor_id, bucket
    FROM (
        SELECT vendor_id, bucket,
            ROW_NUMBER() OVER (PARTITION BY vendor_id ORDER BY order_completed_ts_ist DESC, order_id DESC) AS rn
        FROM vendor_earnings_order_base
    ) ranked
    WHERE rn = 1
),
vendor_earnings_effective_bucket AS (
    SELECT vpb.bucket, pob.order_id, pob.total_order_fare
    FROM vendor_earnings_order_base pob
    INNER JOIN vendor_earnings_period_bucket vpb ON pob.vendor_id = vpb.vendor_id
),
vendor_earnings_bucket_totals AS (
    SELECT bucket, SUM(total_order_fare) AS total_revenue
    FROM vendor_earnings_effective_bucket
    GROUP BY 1
),
vendor_earnings_bucket_pct AS (
    SELECT bucket,
        ROUND(total_revenue * 100.0 / NULLIF(SUM(total_revenue) OVER (), 0), 2) AS revenue_pct
    FROM vendor_earnings_bucket_totals
)
SELECT
    DATE '{ms}' AS month,
    MAX(CASE WHEN bucket = 'GoldPlus' THEN revenue_pct END) AS revenue_pct_goldplus,
    MAX(CASE WHEN bucket = 'Gold' THEN revenue_pct END) AS revenue_pct_gold,
    MAX(CASE WHEN bucket = 'Silver' THEN revenue_pct END) AS revenue_pct_silver,
    MAX(CASE WHEN bucket = 'Bronze' THEN revenue_pct END) AS revenue_pct_bronze,
    MAX(CASE WHEN bucket = 'New' THEN revenue_pct END) AS revenue_pct_new
FROM vendor_earnings_bucket_pct"""


# section -> SQL builder. "derived" resolves to the funnel query; the ratio is
# computed in Python from its raw counts.
SECTION_SQL = {
    "leads":         leads_sql,
    "orders":        orders_sql,
    "derived":       funnel_sql,
    "tpo":           tpo_sql,
    "p80_durations": p80_sql,
    "order_edits":   order_edits_sql,
    "ota":           ota_sql,
    "gac_ctr":       gac_ctr_sql,
    "weekend":              weekend_sql,
    "cac_post_trip":        cac_post_trip_sql,
    "vendor_earnings_pctl": vendor_earnings_pctl_sql,
    "allocation":           allocation_sql,
    "wallet":               wallet_sql,
    "vendor_tpo_top5":      vendor_tpo_top5_sql,
    "addon":                addon_sql,
    "completion":           completion_sql,
    "fare":                 fare_sql,
    "vendor_earnings_bucket": vendor_earnings_bucket_sql,
}


def render(section: str, month: str) -> str:
    if section not in SECTION_SQL:
        raise ValueError(f"no SQL builder for section {section!r}")
    sql = SECTION_SQL[section](month)
    assert_read_only(sql)
    return sql


def assert_read_only(sql: str) -> None:
    """Defense in depth: this layer must never ship anything but one SELECT."""
    body = sql.strip()
    if ";" in body:
        raise ValueError("multiple statements are not allowed")
    if not (body.upper().startswith("WITH") or body.upper().startswith("SELECT")):
        raise ValueError("only SELECT statements are allowed")
    if re.search(r"\b(CREATE|INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|TRUNCATE|COPY|GRANT)\b",
                 body, re.IGNORECASE):
        raise ValueError("write/DDL keyword detected — refusing")
    if ":month" in body or "{month" in body:
        raise ValueError("unsubstituted parameter left in SQL")
