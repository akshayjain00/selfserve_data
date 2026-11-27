#!/usr/bin/env python3
"""Shared library for the HCV intracity ops report: windows, SQL, export loading.

Adapted (cut down) from ~/dev/ops_report_dailydigest/ops-report/opslib.py.
Period math is the reference pipeline's; everything HCV-specific follows the
hcv-data skill (dashboard 6406 definitions). Stdlib only.
"""

from __future__ import annotations

import datetime as _dt
import json
import pathlib
from dataclasses import dataclass, field

IST = _dt.timezone(_dt.timedelta(hours=5, minutes=30))
STRIP_DAYS = 14

MART = "PROD_ELDORIA.MART.HCV_OVERALL_DEMAND_MART"
TIER = "Tier 1"
INTRACITY_SQL = "LOWER(v.serviceability_segment) = 'vanilla'"

# Order-type codes carry no spaces so an export never depends on whitespace.
ORDER_TYPES = {
    "SCHEDULE": "Schedule",
    "EXPRESS": "Express",
    "SPOT_TRAY": "SPOT on Tray",
    "SPOT": "SPOT",
}
ORDER_TYPE_SQL = """CASE
        WHEN o.so_is_express_booking = FALSE THEN 'SCHEDULE'
        WHEN o.so_is_express_booking = TRUE AND o.so_driver_assignment_type <> 4 THEN 'EXPRESS'
        WHEN o.so_is_express_booking = TRUE AND o.so_driver_assignment_type = 4 THEN 'SPOT_TRAY'
        ELSE 'SPOT'
    END"""

# Composable columns of daily_orders (all plain sums over one-row-per-order).
SUM_KEYS = ["DEMAND", "ALLOCATED", "COMPLETED", "CADF", "CADF_CUSTOMER",
            "CADF_PARTNER", "CADF_PORTER", "CBDF", "CBDF_SO", "CBDF_MO", "REVENUE"]

# The Snowflake MCP truncates a result at ~468 KB (measured 2026-11-27: 4,079 of
# 4,274 rows came back). daily_orders is therefore emitted in date chunks; the
# installer refuses any export whose row count differs from Snowflake's numRows.
ORDERS_CHUNK_DAYS = 20

REQUIRED_COLS = {
    "daily_orders": ["D", "CITY", "VM", "OT", "N_ROWS"] + SUM_KEYS,
    "daily_dap": ["D", "CITY", "VM", "DAP", "DAP_DRIVERS"],
    "period_alloc": ["PERIOD", "CUT", "K", "LABEL", "ALLOC_N", "P50", "P90"],
}


# --------------------------------------------------------------------------
# Windows
# --------------------------------------------------------------------------


def _daterange(a: _dt.date, b: _dt.date) -> list[_dt.date]:
    return [a + _dt.timedelta(days=i) for i in range((b - a).days + 1)]


@dataclass
class Periods:
    """Every window the report needs, resolved against a fixed analysis end date."""

    analysis_end: _dt.date
    strip_days: list[_dt.date] = field(default_factory=list)   # last 14 days
    sw_days: list[_dt.date] = field(default_factory=list)      # last 4 same weekdays
    wtd: tuple[_dt.date, _dt.date] = None
    lwtd: tuple[_dt.date, _dt.date] = None
    mtd: tuple[_dt.date, _dt.date] = None
    lmtd: tuple[_dt.date, _dt.date] = None

    def __post_init__(self) -> None:
        ae = self.analysis_end
        self.strip_days = [ae - _dt.timedelta(days=i)
                           for i in range(STRIP_DAYS - 1, -1, -1)]
        self.sw_days = [ae - _dt.timedelta(days=7 * i) for i in range(1, 5)]

        # week: Monday-anchored, same number of elapsed days on both sides
        w_start = ae - _dt.timedelta(days=ae.weekday())
        n_w = (ae - w_start).days + 1
        self.wtd = (w_start, ae)
        lw_start = w_start - _dt.timedelta(days=7)
        self.lwtd = (lw_start, lw_start + _dt.timedelta(days=n_w - 1))

        # month: same day-of-month on both sides, clamped to the shorter month
        m_start = ae.replace(day=1)
        self.mtd = (m_start, ae)
        prev_m_end = m_start - _dt.timedelta(days=1)
        lm_start = prev_m_end.replace(day=1)
        lm_end = min(lm_start + _dt.timedelta(days=ae.day - 1), prev_m_end)
        self.lmtd = (lm_start, lm_end)

    @property
    def windows(self) -> dict[str, tuple[_dt.date, _dt.date]]:
        return {"WTD": self.wtd, "LWTD": self.lwtd, "MTD": self.mtd, "LMTD": self.lmtd}

    @property
    def labels(self) -> dict[str, str]:
        f = "%d %b"
        out = {"day": self.analysis_end.strftime("%a %d %b %Y"),
               "sw4": ", ".join(d.strftime(f) for d in reversed(self.sw_days))}
        for k, (a, b) in self.windows.items():
            out[k.lower()] = (a.strftime(f) if a == b
                              else f"{a.strftime(f)} – {b.strftime(f)}")
        return out

    def all_dates(self) -> list[_dt.date]:
        s: set[_dt.date] = set(self.strip_days) | set(self.sw_days)
        for rng in self.windows.values():
            s |= set(_daterange(*rng))
        return sorted(s)

    def date_range(self) -> tuple[_dt.date, _dt.date]:
        d = self.all_dates()
        return d[0], d[-1]

    def spine(self) -> list[tuple[str, _dt.date, int]]:
        """(period, start, n_days) ranges for the non-composable query."""
        out = [(f"DAY|{d.isoformat()}", d, 1) for d in self.strip_days]
        out += [(f"SWD|{d.isoformat()}", d, 1) for d in self.sw_days]
        out += [(k, a, (b - a).days + 1) for k, (a, b) in self.windows.items()]
        return out

    def period_keys(self) -> list[str]:
        return [lab for lab, _, _ in self.spine()]


# --------------------------------------------------------------------------
# SQL
# --------------------------------------------------------------------------


def tag(name: str, p: Periods) -> str:
    """Run tag stamped into every export as a COLUMN NAME (costs ~4 bytes/row)."""
    return f"TAG__{name}__{p.analysis_end.isoformat()}"


def _spine_cte(p: Periods) -> str:
    ranges = p.spine()
    maxn = max(n for _, _, n in ranges)
    vals = ",\n        ".join(f"('{lab}', '{d.isoformat()}'::date, {n})"
                              for lab, d, n in ranges)
    return f"""spine_def(PERIOD, START_D, NDAYS) AS (
    SELECT * FROM VALUES
        {vals}
),
nums AS (
    SELECT ROW_NUMBER() OVER (ORDER BY NULL) - 1 AS I
    FROM TABLE(GENERATOR(ROWCOUNT => {maxn}))
),
spine AS (
    SELECT sd.PERIOD, DATEADD(day, n.I, sd.START_D) AS D
    FROM spine_def sd
    JOIN nums n ON n.I < sd.NDAYS
)"""


def _base_where(p: Periods, rng: tuple[_dt.date, _dt.date] | None = None) -> str:
    a, b = rng or p.date_range()
    # hcv-data standard base filters + Tier 1 + the Gate-0 intracity filter.
    return f"""o.fo_deleted_at IS NULL
      AND o.customer_mobile <> '0000000001'
      AND DATE(o.order_time) >= '{a.isoformat()}'
      AND DATE(o.order_time) <= '{b.isoformat()}'
      AND g.tier = '{TIER}'
      AND {INTRACITY_SQL}"""


def orders_chunks(p: Periods) -> dict[str, tuple[_dt.date, _dt.date]]:
    """daily_orders split into contiguous date chunks that fit the MCP budget."""
    a, b = p.date_range()
    out, i = {}, 1
    while a <= b:
        e = min(a + _dt.timedelta(days=ORDERS_CHUNK_DAYS - 1), b)
        out[f"daily_orders_{i}"] = (a, e)
        a, i = e + _dt.timedelta(days=1), i + 1
    return out


def sql_daily_orders(p: Periods, name: str = "daily_orders",
                     rng: tuple[_dt.date, _dt.date] | None = None) -> str:
    """Composable order facts at date x city x vehicle_mapping x order_type."""
    return f"""WITH fom AS (
    SELECT ORDER_ID, MAX(NUM_BATCHES_CREATED) AS NB
    FROM PROD_ELDORIA.MART.HCV_FO_MATCHMAKING_MART GROUP BY 1
),
som AS (
    SELECT SCHEDULE_ORDER_ID, MAX(NUM_BATCHES_CREATED) AS NB
    FROM PROD_ELDORIA.MART.HCV_SO_MATCHMAKING_MART GROUP BY 1
),
attr AS (   -- one row per CANCEL_REASON_ID so the join cannot fan out; a reason
            -- carrying two different attributions is labelled 'conflict', which
            -- no split counts, so it surfaces as unattributed CADF in the report
    SELECT CANCEL_REASON_ID,
           IFF(COUNT(DISTINCT LOWER(ATTRIBUTION)) = 1, MAX(LOWER(ATTRIBUTION)), 'conflict') AS ATTRIBUTION
    FROM PROD_ELDORIA.CORE.DIM_CANCEL_REASONS_ATTRIBUTION GROUP BY 1
),
base AS (
    SELECT
        o.unique_id                                             AS UID,
        DATE(o.order_time)                                      AS D,
        o.geo_region_id                                         AS CITY,
        COALESCE(v.vehicle_mapping, 'UNMAPPED')                 AS VM,
        {ORDER_TYPE_SQL}                                        AS OT,
        (o.fo_driver_id IS NOT NULL)                            AS ALLOC,
        o.order_status                                          AS ST,
        GREATEST(COALESCE(som.NB, 0), COALESCE(fom.NB, 0))      AS NB,
        a.ATTRIBUTION                                           AS ATTRIBUTION,
        o.FO_CUSTOMER_FARE_WITHOUT_PREVIOUS_DUE                 AS FARE
    FROM {MART} o
    JOIN PROD_ELDORIA.CORE.DIM_GEO_REGIONS g ON g.geo_region_id = o.geo_region_id
    JOIN PROD_ELDORIA.CORE.DIM_VEHICLES v    ON v.vehicle_id = o.vehicle_id
    LEFT JOIN fom ON fom.ORDER_ID = o.fo_order_id
    LEFT JOIN som ON som.SCHEDULE_ORDER_ID = o.so_id
    LEFT JOIN attr a ON a.CANCEL_REASON_ID = o.fo_cancel_reason_id
    WHERE {_base_where(p, rng)}
)
SELECT
    D, CITY, VM, OT,
    COUNT(*)                                                    AS N_ROWS,
    COUNT(DISTINCT UID)                                         AS DEMAND,
    COUNT_IF(ALLOC)                                             AS ALLOCATED,
    COUNT_IF(ALLOC AND ST = 4)                                  AS COMPLETED,
    COUNT_IF(ALLOC AND ST = 5)                                  AS CADF,
    COUNT_IF(ALLOC AND ST = 5 AND ATTRIBUTION = 'customer')     AS CADF_CUSTOMER,
    COUNT_IF(ALLOC AND ST = 5 AND ATTRIBUTION = 'partner')      AS CADF_PARTNER,
    COUNT_IF(ALLOC AND ST = 5 AND ATTRIBUTION = 'porter')       AS CADF_PORTER,
    COUNT_IF(NOT ALLOC AND (ST = 5 OR ST IS NULL))              AS CBDF,
    COUNT_IF(NOT ALLOC AND (ST = 5 OR ST IS NULL) AND NB = 0)   AS CBDF_SO,
    COUNT_IF(NOT ALLOC AND (ST = 5 OR ST IS NULL) AND NB > 0)   AS CBDF_MO,
    COALESCE(SUM(IFF(ALLOC AND ST = 4, FARE, 0)), 0)            AS REVENUE,
    1 AS "{tag(name, p)}"
FROM base
GROUP BY 1, 2, 3, 4
ORDER BY 1, 2, 3, 4"""


def sql_daily_dap(p: Periods) -> str:
    """Daily active partners (card 55573 logic) at date x city x vehicle_mapping."""
    a, b = p.date_range()
    return f"""SELECT
    D, CITY, VM,
    COUNT(*)                   AS DAP,
    COUNT(DISTINCT DRIVER_ID)  AS DAP_DRIVERS,
    1 AS "{tag('daily_dap', p)}"
FROM (
    SELECT l.day AS D, l.geo_region_id AS CITY, l.driver_id AS DRIVER_ID,
           COALESCE(MAX(v.vehicle_mapping), 'UNMAPPED') AS VM
    FROM PROD_ELDORIA.CORE.FACT_ACTIVE_PARTNERS l
    JOIN PROD_ELDORIA.CORE.DIM_VEHICLES v    ON v.vehicle_id = l.vehicle_id
    JOIN PROD_ELDORIA.CORE.DIM_GEO_REGIONS g ON g.geo_region_id = l.geo_region_id
    WHERE l.day >= '{a.isoformat()}' AND l.day <= '{b.isoformat()}'
      AND v.level0_mapping = 'HCV'
      AND g.tier = '{TIER}'
      AND {INTRACITY_SQL}
    GROUP BY 1, 2, 3
    HAVING SUM(l.business_login_hours) > 0.5
)
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3"""


def sql_period_alloc(p: Periods) -> str:
    """Allocation-time percentiles per window x one-way cut (non-composable).

    Clock and population are card 55527's. Each order is fanned into every
    window it belongs to through the spine; cuts come from GROUPING SETS.
    """
    return f"""WITH {_spine_cte(p)},
base AS (
    SELECT
        DATE(o.order_time)                                      AS D,
        o.geo_region_id::string                                 AS CITY,
        g.city_name                                             AS CITY_NAME,
        COALESCE(v.vehicle_mapping, 'UNMAPPED')                 AS VM,
        {ORDER_TYPE_SQL}                                        AS OT,
        DATEDIFF('second', o.order_time,
                 TO_TIMESTAMP(o.fo_trip_accepted_time) + INTERVAL '330 minutes') AS SECS
    FROM {MART} o
    JOIN PROD_ELDORIA.CORE.DIM_GEO_REGIONS g ON g.geo_region_id = o.geo_region_id
    JOIN PROD_ELDORIA.CORE.DIM_VEHICLES v    ON v.vehicle_id = o.vehicle_id
    WHERE {_base_where(p)}
      AND o.fo_trip_accepted_time IS NOT NULL
),
x AS (
    SELECT s.PERIOD, b.CITY, b.CITY_NAME, b.VM, b.OT, b.SECS
    FROM base b JOIN spine s ON s.D = b.D
    WHERE b.SECS >= 0
)
SELECT
    PERIOD,
    CASE WHEN GROUPING(CITY) = 0 THEN 'CITY'
         WHEN GROUPING(VM) = 0 THEN 'VM'
         WHEN GROUPING(OT) = 0 THEN 'OT'
         ELSE 'ALL' END                                         AS CUT,
    COALESCE(CITY, VM, OT, 'ALL')                               AS K,
    IFF(GROUPING(CITY) = 0, MAX(CITY_NAME), NULL)               AS LABEL,
    COUNT(*)                                                    AS ALLOC_N,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY SECS)           AS P50,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY SECS)           AS P90,
    1 AS "{tag('period_alloc', p)}"
FROM x
GROUP BY GROUPING SETS ((PERIOD), (PERIOD, CITY), (PERIOD, VM), (PERIOD, OT))
ORDER BY 1, 2, 3"""


def queries_for(p: Periods) -> dict[str, str]:
    """name -> SQL for everything this run has to execute."""
    out = {n: sql_daily_orders(p, n, rng) for n, rng in orders_chunks(p).items()}
    out["daily_dap"] = sql_daily_dap(p)
    out["period_alloc"] = sql_period_alloc(p)
    return out


def required_cols(name: str) -> list[str]:
    return REQUIRED_COLS["daily_orders" if name.startswith("daily_orders") else name]


# --------------------------------------------------------------------------
# Export loading (Snowflake MCP JSON -> list of dicts)
# --------------------------------------------------------------------------


class ExportError(ValueError):
    pass


def parse_export(text: str) -> tuple[list[dict], str | None]:
    """Parse one Snowflake MCP result. Returns (rows, tag).

    Refuses a result whose row count differs from the count Snowflake reported,
    so a truncated or paginated response can never be installed.
    """
    try:
        j = json.loads(text)
    except json.JSONDecodeError as e:
        raise ExportError(f"not valid JSON ({e})") from e
    rs = j.get("result_set", j)
    try:
        cols = [c["name"] for c in rs["resultSetMetaData"]["rowType"]]
        data = rs["data"]
        n_expected = int(rs["resultSetMetaData"]["numRows"])
    except (KeyError, TypeError) as e:
        raise ExportError(f"not a Snowflake result set (missing {e})") from e
    if len(data) != n_expected:
        raise ExportError(f"row count {len(data)} != numRows {n_expected} "
                          "(truncated or paginated response)")
    tags = [c for c in cols if c.startswith("TAG__")]
    rows = [dict(zip(cols, r)) for r in data]
    return rows, (tags[0] if tags else None)


def load_export(path) -> list[dict]:
    rows, _ = parse_export(pathlib.Path(path).read_text())
    return rows


def num(v):
    """Snowflake returns every value as a string; blank stays None (never 0)."""
    if v is None or v == "":
        return None
    f = float(v)
    return int(f) if f == int(f) and "." not in str(v) else f
