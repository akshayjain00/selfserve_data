"""Final SELECTs for the session-conversion cards. Each is appended to session_base.sql."""
from pathlib import Path

BASE = (Path(__file__).parent / "session_base.sql").read_text()

FUNNEL = """,
steps AS (
    SELECT 1 AS step_no, '1. PTL Confirm' AS step, arm_name, COUNT(*) AS sessions FROM sessions_in_scope GROUP BY 1,2,3
    UNION ALL SELECT 2, '2. Quote Viewed',  arm_name, SUM(reached_quote)     FROM sessions_in_scope GROUP BY 1,2,3
    UNION ALL SELECT 3, '3. Book Now',      arm_name, SUM(reached_booknow)   FROM sessions_in_scope GROUP BY 1,2,3
    UNION ALL SELECT 4, '4. Order Placed',  arm_name, SUM(reached_order_placed)    FROM sessions_in_scope GROUP BY 1,2,3
    UNION ALL SELECT 5, '5. Completed',     arm_name, SUM(reached_completed) FROM sessions_in_scope GROUP BY 1,2,3
)
SELECT step     AS "Step",
       arm_name  AS "Variant",
       sessions AS "Sessions",
       ROUND(100.0*sessions
             / NULLIF(FIRST_VALUE(sessions) OVER (PARTITION BY arm_name ORDER BY step_no),0),2) AS "% of PTL Confirm",
       ROUND(100.0*sessions
             / NULLIF(LAG(sessions) OVER (PARTITION BY arm_name ORDER BY step_no),0),2)         AS "% of Previous Step"
FROM steps
ORDER BY step_no, arm_name;
"""

CONV_BOOKNOW = """
SELECT arm_name           AS "Variant",
       COUNT(*)          AS "Confirm Sessions",
       SUM(reached_booknow)   AS "Book Now Sessions",
       ROUND(100.0*SUM(reached_booknow)/NULLIF(COUNT(*),0),2) AS "Session Conv % (Confirm → Book Now)"
FROM sessions_in_scope GROUP BY 1 ORDER BY 1;
"""

CONV_QUOTE_BOOKNOW = """
SELECT arm_name           AS "Variant",
       SUM(reached_quote)     AS "Quote Viewed Sessions",
       SUM(reached_booknow)   AS "Book Now Sessions",
       ROUND(100.0*SUM(reached_booknow)/NULLIF(SUM(reached_quote),0),2) AS "Session Conv % (Quote Viewed → Book Now)"
FROM sessions_in_scope GROUP BY 1 ORDER BY 1;
"""

CONV_COMPLETED = """
SELECT arm_name           AS "Variant",
       COUNT(*)          AS "Confirm Sessions",
       SUM(reached_completed) AS "Completed Sessions",
       ROUND(100.0*SUM(reached_completed)/NULLIF(COUNT(*),0),2) AS "Session Conv % (Confirm → Completed)"
FROM sessions_in_scope GROUP BY 1 ORDER BY 1;
"""

# Customer-clustered (delta-method) test of each session-level ratio.
# Per customer: numerator = converting sessions, denominator = confirm sessions. Ratio-of-means per arm,
# conv_rate_var ~ (var_num/mean_den^2 - 2 mean_num cov_num_den/mean_den^3 + mean_num^2 var_den/mean_den^4) / customers. Fixed-sample z test; Statsig's
# console uses sequential testing, so its CIs are wider (~1.85x) though the point estimate matches.
# p-value: two-sided, erfc(|z|/sqrt2) via Abramowitz-Stegun 7.1.26 (abs error < 1.5e-7).
SIGNIFICANCE = """,

-- =========================================================================================
-- PART B — significance test, clustered by customer (delta method)
-- =========================================================================================
customer_totals AS (
    -- One row per customer: how many sessions they had, and how many reached each step.
    SELECT arm_name, customer_id,
           COUNT(*)                  AS confirm_sessions,
           SUM(reached_quote)        AS quote_sessions,
           SUM(reached_booknow)      AS booknow_sessions,
           SUM(reached_order_placed) AS placed_sessions,
           SUM(reached_completed)    AS completed_sessions
    FROM sessions_in_scope GROUP BY 1,2
),
customer_metric_rows AS (
    -- Stack the 5 metrics: numerator / denominator per customer per metric.
              SELECT 1 AS metric_order, 'Confirm → Quote Viewed' AS metric, arm_name, confirm_sessions AS denominator, quote_sessions     AS numerator FROM customer_totals
    UNION ALL SELECT 2,                 'Quote Viewed → Book Now',          arm_name, quote_sessions,                   booknow_sessions                FROM customer_totals WHERE quote_sessions > 0
    UNION ALL SELECT 3,                 'Confirm → Book Now',               arm_name, confirm_sessions,                 booknow_sessions                FROM customer_totals
    UNION ALL SELECT 4,                 'Confirm → Order Placed',           arm_name, confirm_sessions,                 placed_sessions                 FROM customer_totals
    UNION ALL SELECT 5,                 'Confirm → Completed',              arm_name, confirm_sessions,                 completed_sessions              FROM customer_totals
),
arm_stats AS (
    -- Per metric x arm: totals, per-customer means, variances and covariance.
    SELECT metric_order, metric, arm_name,
           IFF(LOWER(arm_name) IN ('control','fail'), 'C', 'T') AS arm_role,
           COUNT(*)                            AS customers,
           SUM(numerator)                      AS total_num,
           SUM(denominator)                    AS total_den,
           AVG(numerator)                      AS mean_num,
           AVG(denominator)                    AS mean_den,
           VAR_POP(numerator)                  AS var_num,
           VAR_POP(denominator)                AS var_den,
           COVAR_POP(numerator, denominator)   AS cov_num_den
    FROM customer_metric_rows GROUP BY 1,2,3
),
arm_rate AS (
    -- Conversion rate = total_num / total_den, and its variance via the delta method.
    SELECT *,
           total_num / NULLIF(total_den, 0) AS conv_rate,
           ( var_num / POWER(mean_den, 2)
             - 2 * mean_num * cov_num_den / POWER(mean_den, 3)
             + POWER(mean_num, 2) * var_den / POWER(mean_den, 4) ) / customers AS conv_rate_var
    FROM arm_stats
),
control_vs_test AS (
    -- Pair each test arm with control for the same metric.
    SELECT ctl.metric_order, ctl.metric,
           ctl.arm_name   AS control_arm,  tst.arm_name   AS test_arm,
           ctl.customers  AS control_customers, tst.customers AS test_customers,
           ctl.total_den  AS control_sessions,  tst.total_den AS test_sessions,
           ctl.conv_rate  AS control_rate,      tst.conv_rate AS test_rate,
           SQRT(ctl.conv_rate_var + tst.conv_rate_var)                                   AS std_error,
           ABS(tst.conv_rate - ctl.conv_rate) / NULLIF(SQRT(ctl.conv_rate_var + tst.conv_rate_var), 0)
             / SQRT(2)                                                                   AS z_over_root2   -- |z|/√2, input to erfc
    FROM arm_rate ctl
    JOIN arm_rate tst
      ON tst.metric = ctl.metric AND ctl.arm_role = 'C' AND tst.arm_role = 'T'
),
pvalue_prep AS (
    SELECT *, 1 / (1 + 0.3275911 * z_over_root2) AS erfc_t FROM control_vs_test
)
SELECT metric                                              AS "Metric",
       control_arm || ' vs ' || test_arm                    AS "Arms",
       control_customers                                   AS "Control Customers",
       test_customers                                      AS "Test Customers",
       control_sessions                                    AS "Control Sessions",
       test_sessions                                       AS "Test Sessions",
       ROUND(100 * control_rate, 2)                        AS "Control %",
       ROUND(100 * test_rate, 2)                           AS "Test %",
       ROUND(100 * (test_rate - control_rate), 2)          AS "Δ (pp)",
       ROUND(100 * (test_rate / NULLIF(control_rate, 0) - 1), 2) AS "Lift %",
       ROUND(100 * (test_rate - control_rate - 1.96 * std_error), 2) AS "95% CI Low (pp)",
       ROUND(100 * (test_rate - control_rate + 1.96 * std_error), 2) AS "95% CI High (pp)",
       -- two-sided p = erfc(|z|/√2), Abramowitz–Stegun 7.1.26 polynomial
       ROUND(erfc_t*(0.254829592+erfc_t*(-0.284496736+erfc_t*(1.421413741+erfc_t*(-1.453152027+erfc_t*1.061405429))))
             * EXP(-z_over_root2*z_over_root2), 4)         AS "p-value",
       IFF(erfc_t*(0.254829592+erfc_t*(-0.284496736+erfc_t*(1.421413741+erfc_t*(-1.453152027+erfc_t*1.061405429))))
             * EXP(-z_over_root2*z_over_root2) < 0.05, 'Yes', 'No') AS "Significant (95%)"
FROM pvalue_prep
ORDER BY metric_order, test_arm;
"""

TREND_BOOKNOW = """
SELECT DATE_TRUNC({{granularity}}, confirm_at)::date AS "Period", arm_name AS "Variant",
       COUNT(*) AS "Confirm Sessions",
       ROUND(100.0*SUM(reached_booknow)/NULLIF(COUNT(*),0),2) AS "Confirm → Book Now %"
FROM sessions_in_scope GROUP BY 1,2 ORDER BY 1,2;
"""

TREND_COMPLETED = """
SELECT DATE_TRUNC({{granularity}}, confirm_at)::date AS "Period", arm_name AS "Variant",
       COUNT(*) AS "Confirm Sessions",
       ROUND(100.0*SUM(reached_completed)/NULLIF(COUNT(*),0),2) AS "Confirm → Completed %"
FROM sessions_in_scope GROUP BY 1,2 ORDER BY 1,2;
"""

SEGMENTS = """,
seg AS (
              SELECT 1 AS dim_ord, 'Customer Category' AS dimension, customer_category AS segment, * FROM sessions_in_scope
    UNION ALL SELECT 2, 'New / Repeat',    customer_tenure,              * FROM sessions_in_scope
    UNION ALL SELECT 3, 'Device Platform', device_platform,              * FROM sessions_in_scope
),
agg AS (
    SELECT dim_ord, dimension, segment,
           IFF(LOWER(arm_name) IN ('control','fail'), 'C', 'T') AS role,
           COUNT(*) AS sessions, SUM(reached_booknow) AS bn, SUM(reached_completed) AS cp
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
SELECT arm_name AS "Variant",
       COUNT(*) AS "Book Now Sessions",
       ROUND(MEDIAN(DATEDIFF('second', confirm_at, booknow_at))/60.0, 1)                                  AS "P50 Confirm → Book Now (min)",
       ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY DATEDIFF('second', confirm_at, booknow_at))/60.0, 1) AS "P75 Confirm → Book Now (min)"
FROM sessions_in_scope
WHERE reached_booknow = 1
GROUP BY 1 ORDER BY 1;
"""

CARDS = {
    "funnel": FUNNEL, "conv_booknow": CONV_BOOKNOW, "conv_completed": CONV_COMPLETED, "conv_quote_booknow": CONV_QUOTE_BOOKNOW,
    "significance": SIGNIFICANCE, "trend_booknow": TREND_BOOKNOW,
    "trend_completed": TREND_COMPLETED, "segments": SEGMENTS, "time_to_book": TIME_TO_BOOK,
}


def sql(key: str) -> str:
    return BASE.rstrip() + CARDS[key]
