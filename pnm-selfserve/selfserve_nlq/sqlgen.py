"""
PnM Self-Serve NL Query Layer — Deterministic SQL generation (v0)
=================================================================
One read-only SELECT per section, with the pipeline's staging logic inlined as
CTEs. The staging bodies are ADAPTED from queries.py, not copied:

  * the CREATE OR REPLACE wrapper is dropped (this layer never writes),
  * the orders CTE's reference to the physical staging table
    PROD_CURATED.NEW_INITIATIVE_ANALYTICS.pnm_mbr_leads is rewritten to the
    inlined leads CTE (no cron dependence, no Monday-run race),
  * the pipeline's named-colon binds (:month_start) — unsupported by the
    Snowflake Python connector — are replaced by validated literal dates
    substituted here, so the SQL you see is byte-for-byte the SQL that runs.

Everything else is bug-for-bug identical to queries.py, including the
staging window (rows created in requested month + previous month), the
status filters, the QUALIFY dedup, and TPO's same-month ticket join.
"""

import re
from datetime import date

MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")


def month_bounds(month: str) -> tuple[str, str]:
    """'2026-05' -> ('2026-05-01', '2026-04-01') = (month_start, month_start_prev)."""
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


# ── Inlined staging CTEs (adapted from CREATE_STG_LEADS / CREATE_STG_ORDERS) ──

CTE_LEADS = """\
leads_base AS (
    SELECT
        f.opp_id,
        f.opp_created_ts,
        f.source,
        f.source_details,
        f.sr_id,
        d.intra_city,
        d.user_flag,
        d.is_nano
    FROM PROD_CURATED.pnm_application.fact_pnm_opprotunity f
    JOIN PROD_CURATED.pnm_application.dim_pnm_opportunity  d USING (opp_id)
    WHERE DATE_TRUNC('month', f.opp_created_ts) IN ('{month_start}', '{month_start_prev}')
      AND d.intra_city = TRUE
      AND d.user_flag  = 'normal'
)"""

CTE_ORDERS = """\
orders_base_raw AS (
    SELECT
        o.order_id,
        o.crn,
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
    FROM PROD_CURATED.pnm_application.orders o
    INNER JOIN PROD_CURATED.pnm_application.pnm_customers  c ON o.customer_id = c.customer_id
    LEFT  JOIN PROD_CURATED.pnm_application.dim_pnm_orders d USING (order_id)
    LEFT  JOIN leads_base                                  l ON o.sr_id = l.sr_id
    WHERE DATE_TRUNC('month', o.o_created_ts) IN ('{month_start}', '{month_start_prev}')
      AND d.intra_city = TRUE
      AND d.user_flag  = 'normal'
      AND o.status    != 4
    QUALIFY ROW_NUMBER() OVER (PARTITION BY o.sr_id ORDER BY o.o_created_ts) = 1
)"""

AGG_LEADS = """\
SELECT
    DATE_TRUNC('month', opp_created_ts)                                          AS month,
    COUNT(DISTINCT opp_id)                                                       AS leads_overall,
    COUNT(DISTINCT CASE WHEN source IN (1,2,3)                  THEN opp_id END) AS leads_app,
    COUNT(DISTINCT CASE WHEN source_details = 'Desktop Website' THEN opp_id END) AS leads_desktop,
    COUNT(DISTINCT CASE WHEN source_details = 'Mobile Website'  THEN opp_id END) AS leads_mobile,
    COUNT(DISTINCT CASE WHEN source = 4                         THEN opp_id END) AS leads_others
FROM leads_base
GROUP BY 1"""

AGG_ORDERS = """\
SELECT
    DATE_TRUNC('month', o_created_ts)                                                AS month,
    COUNT(DISTINCT order_id)                                                         AS orders_overall,
    COUNT(DISTINCT CASE WHEN source IN (1,2,3)                  THEN order_id END)   AS orders_app,
    COUNT(DISTINCT CASE WHEN source_details = 'Desktop Website' THEN order_id END)   AS orders_desktop,
    COUNT(DISTINCT CASE WHEN source_details = 'Mobile Website'  THEN order_id END)   AS orders_mobile,
    COUNT(DISTINCT CASE WHEN source = 4                         THEN order_id END)   AS orders_others
FROM orders_base_raw
GROUP BY 1"""


def leads_sql(month: str) -> str:
    ms, msp = month_bounds(month)
    cte = CTE_LEADS.format(month_start=ms, month_start_prev=msp)
    return f"WITH {cte}\n{AGG_LEADS}\nORDER BY 1"


def orders_sql(month: str) -> str:
    ms, msp = month_bounds(month)
    ctes = (CTE_LEADS + ",\n" + CTE_ORDERS).format(month_start=ms, month_start_prev=msp)
    return f"WITH {ctes}\n{AGG_ORDERS}\nORDER BY 1"


def funnel_sql(month: str) -> str:
    """Leads + orders aggregates joined on month — the input for derived
    metrics, matching runner.py's inner merge of the two DataFrames.
    Ratios are computed in Python from these raw counts (never averaged)."""
    ms, msp = month_bounds(month)
    ctes = (CTE_LEADS + ",\n" + CTE_ORDERS).format(month_start=ms, month_start_prev=msp)
    return f"""WITH {ctes},
leads_monthly AS (
{AGG_LEADS}
),
orders_monthly AS (
{AGG_ORDERS}
)
SELECT
    l.month,
    l.leads_overall, l.leads_app, l.leads_desktop, l.leads_mobile, l.leads_others,
    o.orders_overall, o.orders_app, o.orders_desktop, o.orders_mobile, o.orders_others
FROM leads_monthly  l
JOIN orders_monthly o ON l.month = o.month
ORDER BY 1"""


def tpo_sql(month: str) -> str:
    ms, msp = month_bounds(month)
    ctes = (CTE_LEADS + ",\n" + CTE_ORDERS).format(month_start=ms, month_start_prev=msp)
    # TICKET-SIDE ADAPTATION (owner-approved 2026-07-07, ~90% confidence from Data
    # Catalog evidence): the pipeline's guessed PROD_CURATED.pnm_application.tickets
    # does not exist. The PnM tickets table is PROD_CURATED.sfms_public.hs_tickets;
    # it has no order_id (join on crn / hs_order_id) and the status-at-creation
    # column is named order_status_when_ticket_created (not order_status_at_creation).
    # raised_by, created_at, and the detractor filter are unchanged (confirmed to exist).
    # NOTE: the surrounding order base (orders_base_raw) still references columns that
    # do not exist on the configured raw orders table — see ORDERS_SOURCE_DECISION in
    # metrics_registry. This query is not executable end-to-end until that is resolved.
    return f"""WITH {ctes},
order_base AS (
    SELECT
        o.order_id,
        o.crn,
        DATE_TRUNC('month', a.completed_ts) AS alloc_month
    FROM orders_base_raw o
    JOIN PROD_CURATED.pnm_application.order_allocation_infos a ON o.order_id = a.order_id
    WHERE o.is_nano = FALSE
      AND a.completed_ts IS NOT NULL
),
ticket_data AS (
    SELECT t.id AS ticket_id, t.crn, t.created_at, t.raised_by, t.order_status_when_ticket_created
    FROM PROD_CURATED.sfms_public.hs_tickets t
    JOIN order_base b ON t.crn = b.crn
    WHERE LOWER(t.raised_by) NOT LIKE '%detractor%'
),
monthly AS (
    SELECT
        b.alloc_month                                                                   AS month,
        COUNT(DISTINCT b.order_id)                                                      AS orders_base,
        COUNT(t.ticket_id)                                                              AS tickets_overall,
        COUNT(CASE WHEN t.raised_by IN ('Vendor-Owner','Vendor-Supervisor') THEN 1 END) AS tickets_vendor,
        COUNT(CASE WHEN t.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                   THEN 1 END)                                                          AS tickets_pre_trip,
        COUNT(CASE WHEN t.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_pre_trip_cust,
        COUNT(CASE WHEN t.order_status_when_ticket_created IN ('trip_started','shifting_started')
                   THEN 1 END)                                                          AS tickets_trip_shift,
        COUNT(CASE WHEN t.order_status_when_ticket_created IN ('trip_started','shifting_started')
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_trip_shift_cust,
        COUNT(CASE WHEN t.order_status_when_ticket_created = 'pickup_completed' THEN 1 END) AS tickets_pickup,
        COUNT(CASE WHEN t.order_status_when_ticket_created = 'pickup_completed'
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_pickup_cust,
        COUNT(CASE WHEN t.order_status_when_ticket_created = 'completed' THEN 1 END)     AS tickets_completed,
        COUNT(CASE WHEN t.order_status_when_ticket_created = 'completed'
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_completed_cust,
        COUNT(CASE WHEN t.order_status_when_ticket_created = 'cancelled' THEN 1 END)     AS tickets_cancelled,
        COUNT(CASE WHEN t.order_status_when_ticket_created = 'cancelled'
                        AND t.raised_by = 'Customer' THEN 1 END)                        AS tickets_cancelled_cust
    FROM order_base b
    LEFT JOIN ticket_data t ON b.crn = t.crn
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
ORDER BY 1"""


# section -> SQL builder. "derived" resolves to the funnel query; the ratio is
# computed in Python from its raw counts.
SECTION_SQL = {
    "leads":   leads_sql,
    "orders":  orders_sql,
    "derived": funnel_sql,
    "tpo":     tpo_sql,
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
