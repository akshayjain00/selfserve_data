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
    COUNT(DISTINCT opp_id)                                              AS leads_overall,
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
    l.leads_overall, l.leads_app, l.leads_desktop, l.leads_mobile, l.leads_others,
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


# section -> SQL builder. "derived" resolves to the funnel query; the ratio is
# computed in Python from its raw counts.
SECTION_SQL = {
    "leads":         leads_sql,
    "orders":        orders_sql,
    "derived":       funnel_sql,
    "tpo":           tpo_sql,
    "p80_durations": p80_sql,
    "order_edits":   order_edits_sql,
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
