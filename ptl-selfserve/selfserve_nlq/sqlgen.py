# sqlgen.py
"""
PTL Self-Serve — deterministic READ-ONLY SQL builder (dry-run).
One parameterised SELECT per section on RAW prod_curated.partload_application (D2).

HONESTY CONTRACT (iteration-2 candidate SQL, not validated numbers):
  • orders.state enum 3=completed/4=cancelled ASSUMED (P1) — stamped inline.
  • offline status_code -> canonical enum is UNMAPPED: mapped via a flagged CASE that yields NULL
    for anything unrecognised, and gated by OFFLINE_STATUS_CONFIRMED. So on incl_offline, offline
    rows count toward `placed` but not toward completed/cbdf/cadf until the mapping is confirmed.
  • column/join names not confirmed against the source card (connectors were down) are marked
    /*⚠VERIFY ...*/ and MUST be reconciled before any --execute.
  • both_bases metrics (D3) emit TWO rows — basis='incl_offline' / 'excl_offline'.
  • ratios NOT computed here — SELECTs return raw COUNTS; ask.py divides (aggregate-then-ratio;
    divide-by-zero -> None).
Every rendered string passes core.assert_read_only.

Hardened after the 2026-07-23 blind-checker review (see coordination/DECISIONS D-005):
  no fan-out (EXISTS not JOIN), NOT EXISTS not NOT IN, IST month boundaries, namespaced order keys,
  business-user filter applied, effective-FF has its own denominator, offline state gated.
"""
from core import assert_read_only

_ORDERS = "prod_curated.partload_application.orders"
_OV = "prod_curated.partload_application.order_vehicles"
_CR = "prod_curated.partload_application.order_cancellation_reasons"
_INT = "prod_curated.partload_analytics.ptl_internal_users"
_OFFLINE = "prod_curated.gsheet_sync.ptl_offline_orders"
_BATCH = "prod_curated.partload_application.batched_orders_v1"
_FE = "prod_curated.partload_analytics.ptl_fe_events"
_CUST = "prod_curated.oms_public.customers"


def month_bounds(month: str) -> tuple[str, str]:
    y, m = (int(x) for x in month.split("-"))
    ms = f"{y:04d}-{m:02d}-01"
    ny, nm = (y + 1, 1) if m == 12 else (y, m + 1)
    return ms, f"{ny:04d}-{nm:02d}-01"


def _online_base(ms: str, me: str) -> str:
    # One row per order (EXISTS, no join fan-out). Business, non-internal, month = IST calendar month.
    return f"""online AS (
    SELECT
        'ON:' || o.external_id                                          AS okey,
        o.state                                                         AS state,   /*⚠VERIFY enum 3=completed,4=cancelled (P1)*/
        o.estimated_fare                                                AS revenue, /*⚠VERIFY revenue col + AOV date-basis updated_at vs created_at (§3.6)*/
        CASE WHEN EXISTS (SELECT 1 FROM {_OV} ov
                          WHERE ov.order_external_id = o.external_id)    /*⚠VERIFY join key + is_active; 49366-style signal, reconcile vs 4793 (D5)*/
             THEN 1 ELSE 0 END                                          AS vehicle_assigned
    FROM {_ORDERS} o
    WHERE o.created_at >= DATEADD('minute', -330, DATE '{ms}')          -- IST month start (data is UTC; CLAUDE.md rule; bare column preserves pruning)
      AND o.created_at <  DATEADD('minute', -330, DATE '{me}')
      AND NOT EXISTS (SELECT 1 FROM {_INT} u WHERE u.mobile = o.customer_mobile)   -- internal/test exclusion (NOT EXISTS avoids NULL trap)
      AND EXISTS (SELECT 1 FROM {_CUST} c
                  WHERE c.mobile = o.customer_mobile AND c.frequency IN (1,2,3,4)) /*⚠VERIFY business filter: oms_public vs dim_customers + join key (§3.5)*/
)"""


def _offline_base(ms: str) -> str:
    return f"""offline AS (
    SELECT
        'OFF:' || so.order_crn                                          AS okey,    /*⚠VERIFY offline col names*/
        CASE so.status_code                                                          /*⚠VERIFY offline status_code -> enum UNMAPPED; unrecognised -> NULL (not counted). Gated by OFFLINE_STATUS_CONFIRMED*/
             WHEN 'completed' THEN 3 WHEN 'cancelled' THEN 4 ELSE NULL END AS state,
        so.fare                                                         AS revenue, /*⚠VERIFY*/
        0                                                               AS vehicle_assigned /*⚠VERIFY offline allocation unknown -> excluded from cbdf/cadf (state gated NULL anyway)*/
    FROM {_OFFLINE} so
    WHERE so.month_start = DATE '{ms}'                                  /*⚠VERIFY offline month column + IST alignment*/
)"""


def orders_sql(month: str) -> str:
    """Demand / fulfilment / cancellations / AOV raw counts, one row per basis."""
    ms, me = month_bounds(month)
    agg = """SELECT
        {basis} AS basis,
        COUNT(DISTINCT okey)                                            AS placed,
        COUNT(DISTINCT CASE WHEN state = 3 THEN okey END)               AS completed,
        COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 0 THEN okey END) AS cbdf_cancels,
        COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 1 THEN okey END) AS cadf_cancels,
        COUNT(DISTINCT okey)
          - COUNT(DISTINCT CASE WHEN state = 4 AND vehicle_assigned = 0 THEN okey END) AS placed_less_cbdf,
        SUM(CASE WHEN state = 3 THEN revenue ELSE 0 END)               AS revenue_completed
    FROM {src}"""
    both = "(SELECT okey,state,revenue,vehicle_assigned FROM online UNION ALL SELECT okey,state,revenue,vehicle_assigned FROM offline)"
    incl = agg.format(basis="'incl_offline'", src=both)
    excl = agg.format(basis="'excl_offline'", src="online")
    sql = f"WITH {_online_base(ms, me)},\n{_offline_base(ms)}\n{incl}\nUNION ALL\n{excl}"
    assert_read_only(sql)
    return sql


def trips_sql(month: str) -> str:
    ms, me = month_bounds(month)
    sql = f"""WITH trips AS (
    SELECT b.batch_id                                                   AS batch_id,   /*⚠VERIFY batch grain vs card 33461*/
           COUNT(DISTINCT o.external_id)                                AS orders_on_trip
    FROM {_BATCH} b
    JOIN {_ORDERS} o ON o.external_id = b.order_external_id             /*⚠VERIFY join*/
    WHERE o.created_at >= DATEADD('minute', -330, DATE '{ms}')
      AND o.created_at <  DATEADD('minute', -330, DATE '{me}')
      AND o.state = 3
    GROUP BY b.batch_id
)
SELECT 'excl_offline' AS basis,
       SUM(CASE WHEN orders_on_trip >= 2 THEN orders_on_trip ELSE 0 END) AS clubbed_orders,
       COUNT(CASE WHEN orders_on_trip >= 2 THEN 1 END)                   AS clubbing_trips
FROM trips"""
    assert_read_only(sql)
    return sql


def session_sql(month: str) -> str:
    """Business session -> order conversion. Offline base does NOT apply (no session)."""
    ms, me = month_bounds(month)
    sql = f"""WITH s AS (
    SELECT e.session_id                                                 AS session_id, /*⚠VERIFY fe_events schema vs card 48491*/
           MAX(CASE WHEN e.event = 'order_placed' THEN 1 ELSE 0 END)    AS placed_order
    FROM {_FE} e
    WHERE e.event_ts >= DATEADD('minute', -330, DATE '{ms}')
      AND e.event_ts <  DATEADD('minute', -330, DATE '{me}')
      AND e.user_type = 'Business'                                      /*⚠VERIFY business classification*/
      AND NOT EXISTS (SELECT 1 FROM {_INT} u WHERE u.mobile = e.mobile)
    GROUP BY e.session_id
)
SELECT 'excl_offline' AS basis, SUM(placed_order) AS orders, COUNT(*) AS sessions
FROM s"""
    assert_read_only(sql)
    return sql


def retention_sql(month: str) -> str:
    ms, me = month_bounds(month)
    _, me2 = month_bounds(me[:7])
    sql = f"""WITH m0 AS (
    SELECT DISTINCT o.customer_mobile AS mobile
    FROM {_ORDERS} o
    WHERE o.created_at >= DATEADD('minute', -330, DATE '{ms}')
      AND o.created_at <  DATEADD('minute', -330, DATE '{me}') AND o.state = 3
      AND NOT EXISTS (SELECT 1 FROM {_INT} u WHERE u.mobile = o.customer_mobile)
      AND EXISTS (SELECT 1 FROM {_CUST} c WHERE c.mobile = o.customer_mobile AND c.frequency IN (1,2,3,4)) /*⚠VERIFY business filter (§3.5); completed-vs-placed basis vs dashboard 4569*/
),
m1 AS (
    SELECT DISTINCT o.customer_mobile AS mobile
    FROM {_ORDERS} o
    WHERE o.created_at >= DATEADD('minute', -330, DATE '{me}')
      AND o.created_at <  DATEADD('minute', -330, DATE '{me2}') AND o.state = 3
)
SELECT 'excl_offline' AS basis,
       (SELECT COUNT(*) FROM m0)                                        AS m0_business_users,
       (SELECT COUNT(*) FROM m0 WHERE mobile IN (SELECT mobile FROM m1)) AS m0_retained"""
    assert_read_only(sql)
    return sql


SECTION_BUILDER = {"orders": orders_sql, "trips": trips_sql, "session": session_sql, "retention": retention_sql}

# metric_id -> (builder key, kind, spec). ratio spec = (num_col, den_col, scale).
METRIC_PLAN = {
    "completed_orders_business":   ("orders", "simple", "completed"),
    "total_fulfilment_pct":        ("orders", "ratio", ("completed", "placed", 100.0)),
    "effective_fulfilment_pct":    ("orders", "ratio", ("completed", "placed_less_cbdf", 100.0)),  # ⚠VERIFY vs card 48581 'customer-attributed' denom (cbdf ≈ approximation)
    "cbdf_pct":                    ("orders", "ratio", ("cbdf_cancels", "placed", 100.0)),
    "cadf_pct":                    ("orders", "ratio", ("cadf_cancels", "placed", 100.0)),
    "aov":                         ("orders", "ratio", ("revenue_completed", "completed", 1.0)),
    "avg_orders_per_trip":         ("trips", "ratio", ("clubbed_orders", "clubbing_trips", 1.0)),
    "business_session_conversion": ("session", "ratio", ("orders", "sessions", 100.0)),
    "m1_business_retention_pct":   ("retention", "ratio", ("m0_retained", "m0_business_users", 100.0)),
    "nsm_txn_business_customers":  ("orders", "authored", "distinct_business_customers"),  # deferred: column not emitted; NSM authored, no card
    "new_business_users":          ("orders", "authored", "new_business_users"),           # deferred: needs first-order-ever logic
}
