"""Final SELECTs for the session-conversion cards. Each is appended to session_base.sql."""
from pathlib import Path

BASE = (Path(__file__).parent / "session_base.sql").read_text()

FUNNEL = """,
steps AS (
    SELECT 1 AS step_no, '1. PTL Confirm' AS step, variant, COUNT(*) AS sessions FROM scoped GROUP BY 1,2,3
    UNION ALL SELECT 2, '2. Quote Viewed',  variant, SUM(is_quote)     FROM scoped GROUP BY 1,2,3
    UNION ALL SELECT 3, '3. Book Now',      variant, SUM(is_booknow)   FROM scoped GROUP BY 1,2,3
    UNION ALL SELECT 4, '4. Order Placed',  variant, SUM(is_placed)    FROM scoped GROUP BY 1,2,3
    UNION ALL SELECT 5, '5. Completed',     variant, SUM(is_completed) FROM scoped GROUP BY 1,2,3
)
SELECT step     AS "Step",
       variant  AS "Variant",
       sessions AS "Sessions",
       ROUND(100.0*sessions
             / NULLIF(FIRST_VALUE(sessions) OVER (PARTITION BY variant ORDER BY step_no),0),2) AS "% of PTL Confirm",
       ROUND(100.0*sessions
             / NULLIF(LAG(sessions) OVER (PARTITION BY variant ORDER BY step_no),0),2)         AS "% of Previous Step"
FROM steps
ORDER BY step_no, variant;
"""

CONV_BOOKNOW = """
SELECT variant           AS "Variant",
       COUNT(*)          AS "Confirm Sessions",
       SUM(is_booknow)   AS "Book Now Sessions",
       ROUND(100.0*SUM(is_booknow)/NULLIF(COUNT(*),0),2) AS "Session Conv % (Confirm → Book Now)"
FROM scoped GROUP BY 1 ORDER BY 1;
"""

CONV_QUOTE_BOOKNOW = """
SELECT variant           AS "Variant",
       SUM(is_quote)     AS "Quote Viewed Sessions",
       SUM(is_booknow)   AS "Book Now Sessions",
       ROUND(100.0*SUM(is_booknow)/NULLIF(SUM(is_quote),0),2) AS "Session Conv % (Quote Viewed → Book Now)"
FROM scoped GROUP BY 1 ORDER BY 1;
"""

CONV_COMPLETED = """
SELECT variant           AS "Variant",
       COUNT(*)          AS "Confirm Sessions",
       SUM(is_completed) AS "Completed Sessions",
       ROUND(100.0*SUM(is_completed)/NULLIF(COUNT(*),0),2) AS "Session Conv % (Confirm → Completed)"
FROM scoped GROUP BY 1 ORDER BY 1;
"""

# Customer-clustered (delta-method) test of each session-level ratio.
# Per customer: num = converting sessions, den = confirm sessions. Ratio-of-means per arm,
# Var(R) ~ (vx/my^2 - 2 mx cxy/my^3 + mx^2 vy/my^4) / n. Fixed-sample z test; Statsig's
# console uses sequential testing, so its CIs are wider (~1.85x) though the point estimate matches.
# p-value: two-sided, erfc(|z|/sqrt2) via Abramowitz-Stegun 7.1.26 (abs error < 1.5e-7).
SIGNIFICANCE = """,
per_cust AS (
    SELECT variant, customer_id,
           COUNT(*) AS den, SUM(is_quote) AS q, SUM(is_booknow) AS b,
           SUM(is_placed) AS p, SUM(is_completed) AS c
    FROM scoped GROUP BY 1,2
),
lng AS (
              SELECT 1 AS ord, 'Confirm → Quote Viewed' AS metric, variant, den, q AS num FROM per_cust
    UNION ALL SELECT 2, 'Quote Viewed → Book Now', variant, q, b FROM per_cust WHERE q > 0
    UNION ALL SELECT 3, 'Confirm → Book Now',     variant, den, b FROM per_cust
    UNION ALL SELECT 4, 'Confirm → Order Placed', variant, den, p FROM per_cust
    UNION ALL SELECT 5, 'Confirm → Completed',    variant, den, c FROM per_cust
),
arm AS (
    SELECT ord, metric, variant,
           IFF(LOWER(variant) IN ('control','fail'), 'C', 'T') AS role,
           COUNT(*) AS n, SUM(num) AS sx, SUM(den) AS sy,
           AVG(num) AS mx, AVG(den) AS my,
           VAR_POP(num) AS vx, VAR_POP(den) AS vy, COVAR_POP(num, den) AS cxy
    FROM lng GROUP BY 1,2,3
),
arm2 AS (
    SELECT *, sx/NULLIF(sy,0) AS r,
           (vx/POWER(my,2) - 2*mx*cxy/POWER(my,3) + POWER(mx,2)*vy/POWER(my,4)) / n AS var_r
    FROM arm
),
pair AS (
    SELECT c.ord, c.metric, c.variant AS control_arm, t.variant AS test_arm,
           c.n AS cust_c, t.n AS cust_t, c.sy AS sess_c, t.sy AS sess_t,
           c.r AS rc, t.r AS rt, SQRT(c.var_r + t.var_r) AS se,
           ABS(t.r - c.r) / NULLIF(SQRT(c.var_r + t.var_r),0) / SQRT(2) AS x
    FROM arm2 c JOIN arm2 t ON t.metric = c.metric AND c.role = 'C' AND t.role = 'T'
),
pv AS (
    SELECT *, 1/(1+0.3275911*x) AS tt FROM pair
)
SELECT metric                                   AS "Metric",
       control_arm || ' vs ' || test_arm         AS "Arms",
       cust_c                                   AS "Control Customers",
       cust_t                                   AS "Test Customers",
       sess_c                                   AS "Control Sessions",
       sess_t                                   AS "Test Sessions",
       ROUND(100*rc, 2)                         AS "Control %",
       ROUND(100*rt, 2)                         AS "Test %",
       ROUND(100*(rt-rc), 2)                    AS "Δ (pp)",
       ROUND(100*(rt/NULLIF(rc,0)-1), 2)        AS "Lift %",
       ROUND(100*(rt-rc-1.96*se), 2)            AS "95% CI Low (pp)",
       ROUND(100*(rt-rc+1.96*se), 2)            AS "95% CI High (pp)",
       ROUND(tt*(0.254829592+tt*(-0.284496736+tt*(1.421413741+tt*(-1.453152027+tt*1.061405429))))
             * EXP(-x*x), 4)                    AS "p-value",
       IFF(tt*(0.254829592+tt*(-0.284496736+tt*(1.421413741+tt*(-1.453152027+tt*1.061405429))))
             * EXP(-x*x) < 0.05, 'Yes', 'No')   AS "Significant (95%)"
FROM pv
ORDER BY ord, test_arm;
"""

TREND_BOOKNOW = """
SELECT DATE_TRUNC({{granularity}}, t1)::date AS "Period", variant AS "Variant",
       COUNT(*) AS "Confirm Sessions",
       ROUND(100.0*SUM(is_booknow)/NULLIF(COUNT(*),0),2) AS "Confirm → Book Now %"
FROM scoped GROUP BY 1,2 ORDER BY 1,2;
"""

TREND_COMPLETED = """
SELECT DATE_TRUNC({{granularity}}, t1)::date AS "Period", variant AS "Variant",
       COUNT(*) AS "Confirm Sessions",
       ROUND(100.0*SUM(is_completed)/NULLIF(COUNT(*),0),2) AS "Confirm → Completed %"
FROM scoped GROUP BY 1,2 ORDER BY 1,2;
"""

SEGMENTS = """,
seg AS (
              SELECT 1 AS dim_ord, 'Customer Category' AS dimension, customer_category AS segment, * FROM scoped
    UNION ALL SELECT 2, 'New / Repeat',    customer_tenure,              * FROM scoped
    UNION ALL SELECT 3, 'Device Platform', device_platform,              * FROM scoped
),
agg AS (
    SELECT dim_ord, dimension, segment,
           IFF(LOWER(variant) IN ('control','fail'), 'C', 'T') AS role,
           COUNT(*) AS sessions, SUM(is_booknow) AS bn, SUM(is_completed) AS cp
    FROM seg GROUP BY 1,2,3,4
)
SELECT dimension AS "Dimension", segment AS "Segment",
       SUM(IFF(role='C', sessions, 0)) AS "Control Sessions",
       SUM(IFF(role='T', sessions, 0)) AS "Test Sessions",
       ROUND(100.0*SUM(IFF(role='C',bn,0))/NULLIF(SUM(IFF(role='C',sessions,0)),0),2) AS "Control Book Now %",
       ROUND(100.0*SUM(IFF(role='T',bn,0))/NULLIF(SUM(IFF(role='T',sessions,0)),0),2) AS "Test Book Now %",
       ROUND("Test Book Now %" - "Control Book Now %", 2)                           AS "Book Now Δ (pp)",
       ROUND(100.0*SUM(IFF(role='C',cp,0))/NULLIF(SUM(IFF(role='C',sessions,0)),0),2) AS "Control Completed %",
       ROUND(100.0*SUM(IFF(role='T',cp,0))/NULLIF(SUM(IFF(role='T',sessions,0)),0),2) AS "Test Completed %",
       ROUND("Test Completed %" - "Control Completed %", 2)                         AS "Completed Δ (pp)"
FROM agg
GROUP BY dim_ord, dimension, segment
ORDER BY dim_ord, "Control Sessions" + "Test Sessions" DESC;
"""

TIME_TO_BOOK = """
SELECT variant AS "Variant",
       COUNT(*) AS "Book Now Sessions",
       ROUND(MEDIAN(DATEDIFF('second', t1, t3))/60.0, 1)                                  AS "P50 Confirm → Book Now (min)",
       ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DATEDIFF('second', t1, t3))/60.0, 1) AS "P75 Confirm → Book Now (min)"
FROM scoped
WHERE is_booknow = 1
GROUP BY 1 ORDER BY 1;
"""

CARDS = {
    "funnel": FUNNEL, "conv_booknow": CONV_BOOKNOW, "conv_completed": CONV_COMPLETED, "conv_quote_booknow": CONV_QUOTE_BOOKNOW,
    "significance": SIGNIFICANCE, "trend_booknow": TREND_BOOKNOW,
    "trend_completed": TREND_COMPLETED, "segments": SEGMENTS, "time_to_book": TIME_TO_BOOK,
}


def sql(key: str) -> str:
    return BASE.rstrip() + CARDS[key]
