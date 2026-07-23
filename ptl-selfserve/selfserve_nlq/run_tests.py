# run_tests.py
"""Dry-run test harness for the PTL self-serve prototype. Validates ENGINE MECHANICS only
(resolution, read-only guard, both-bases emission, aggregate-then-ratio, the P1 execute gate).
It does NOT validate numbers — that is the owner-run reconciliation round. No network, no prod.
Also renders one SQL per section to tests_output/ for owner review."""
import os
from pathlib import Path
import core, sqlgen, ask
from metrics_registry import METRICS, STATE_ENUM_CONFIRMED

MONTH = "2026-04"
OUT = Path(__file__).parent / "tests_output"
_p = _f = 0


def ok(cond, name):
    global _p, _f
    if cond: _p += 1
    else: _f += 1; print(f"  FAIL: {name}")


# 1. closed-world resolver
for q, exp in [("what was fulfilment in april", "total_fulfilment_pct"),
               ("cbdf", "cbdf_pct"), ("aov", "aov"), ("clubbing ratio", "avg_orders_per_trip"),
               ("north star", "nsm_txn_business_customers")]:
    mid, _ = core.resolve(q, METRICS); ok(mid == exp, f"resolve {q!r} -> {exp} (got {mid})")
for q in ["city-wise fulfilment", "weekly cbdf", "median time to allocate", "profit margin last quarter"]:
    mid, _ = core.resolve(q, METRICS); ok(mid is None, f"refuse unsupported/unknown {q!r}")

# 2. read-only guard
def _ex(f):
    try: f(); return False
    except Exception: return True
ok(_ex(lambda: core.assert_read_only("DELETE FROM x")), "guard rejects DELETE")
ok(_ex(lambda: core.assert_read_only("SELECT 1; SELECT 2")), "guard rejects multi-statement")
ok(_ex(lambda: core.assert_read_only("SELECT * FROM t WHERE d >= '{month}'")), "guard rejects unsubstituted param")
ok(not _ex(lambda: core.assert_read_only("SELECT 'we never DELETE rows' AS note")), "guard allows DELETE inside a string literal")

# 3. every metric with a plan renders + passes the guard
OUT.mkdir(exist_ok=True)
rendered = {}
for mid, plan in sqlgen.METRIC_PLAN.items():
    builder = sqlgen.SECTION_BUILDER[plan[0]]
    try:
        sql = builder(MONTH); core.assert_read_only(sql); rendered[plan[0]] = sql; ok(True, f"render {mid}")
    except Exception as e:
        ok(False, f"render {mid}: {e}")
for section, sql in rendered.items():
    (OUT / f"rendered_{section}_{MONTH}.sql").write_text(sql + "\n")

# 4. both_bases metrics emit BOTH bases; session (both_bases=False) does not
osql = sqlgen.orders_sql(MONTH)
ok("incl_offline" in osql and "excl_offline" in osql, "orders SQL emits both bases (D3)")
ssql = sqlgen.session_sql(MONTH)
ok("incl_offline" not in ssql, "session SQL has no offline base (D6 note)")
ok(METRICS["business_session_conversion"].both_bases is False, "registry: session both_bases=False")

# 5. aggregate-then-ratio + divide-by-zero (never average daily ratios)
plan = sqlgen.METRIC_PLAN["total_fulfilment_pct"]
rows = {"incl_offline": {"completed": 66, "placed": 100}, "excl_offline": {"completed": 60, "placed": 90}}
vals = ask.compute(rows, plan)
ok(vals["incl_offline"] == 66.0 and vals["excl_offline"] == round(60/90*100, 2), "ratio computed per-basis from raw counts")
ok(ask.compute({"b": {"completed": 5, "placed": 0}}, plan)["b"] is None, "divide-by-zero -> None")

# 6. the P1 execute gate is armed
ok(STATE_ENUM_CONFIRMED is False, "P1 gate armed: state enum unconfirmed -> --execute blocks")

# 7. hardening from the 2026-07-23 blind-check review
tf = sqlgen.METRIC_PLAN["total_fulfilment_pct"][2]
ef = sqlgen.METRIC_PLAN["effective_fulfilment_pct"][2]
ok(tf[1] == "placed" and ef[1] == "placed_less_cbdf" and tf != ef, "effective FF != total FF (distinct denominator)")
ok("NOT EXISTS" in osql and " NOT IN (" not in osql, "internal exclusion uses NOT EXISTS (no NULL trap / NOT IN)")
ok("DATEADD('minute', -330" in osql, "month window shifted to IST (UTC data)")
ok("'ON:'" in osql and "'OFF:'" in osql, "order keys namespaced across online/offline (no cross-source dedup)")
ok("EXISTS (SELECT 1 FROM prod_curated.oms_public.customers" in osql, "business-user filter applied")
ok("ELSE NULL END AS state" in osql, "offline status maps unrecognised -> NULL (not counted)")
ok(_ex(lambda: core.assert_read_only("SELECT SYSTEM$WAIT(1)")), "guard rejects SYSTEM$ function")
ok(_ex(lambda: core.assert_read_only("SELECT * FROM t WHERE d = DATE '<ms>'")), "guard rejects <placeholder>")
ok(not _ex(lambda: core.assert_read_only("SELECT 1 /* a block comment */ FROM t")), "guard allows a benign block comment")

print(f"\n{_p} passed, {_f} failed  ({len(rendered)} SQL rendered to tests_output/)")
raise SystemExit(1 if _f else 0)
