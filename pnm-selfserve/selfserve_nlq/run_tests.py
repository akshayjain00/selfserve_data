"""
Dry-run test harness for the v0 self-serve layer.

Runs 6 questions per built section (leads / orders / derived / tpo) plus
refusal cases through: NL resolution -> gate -> SQL render -> read-only checks,
and writes a full report to tests_output/dry_run_report.md.

This harness cannot validate NUMBERS (no warehouse access from this
environment) — numeric validation happens in the execution round after the
owner approves the rendered SQL. What it does validate:
  * every question resolves to the intended metric id (or refuses as intended)
  * every rendered SQL passes assert_read_only, has both window months
    substituted, contains no leftover binds, and hits only expected tables
  * MTD labeling triggers exactly for the current calendar month
"""

import re
import sys
from datetime import date
from pathlib import Path

from metrics_registry import METRICS, SECTIONS, resolve
import sqlgen

OUT = Path(__file__).parent / "tests_output"

EXPECTED_TABLES = {
    "PROD_CURATED.pnm_application.fact_pnm_opprotunity",
    "PROD_CURATED.pnm_application.dim_pnm_opportunity",
    "PROD_CURATED.pnm_application.orders",
    "PROD_CURATED.pnm_application.pnm_customers",
    "PROD_CURATED.pnm_application.dim_pnm_orders",
    "PROD_CURATED.pnm_application.order_allocation_infos",
    "PROD_CURATED.sfms_public.hs_tickets",  # owner-approved ticket source (was guessed .tickets)
}

# (question, month, expected metric id)  — resolution + render must succeed
ANSWERABLE = [
    # leads
    ("How many leads did we get in May 2026?",                    "2026-05", "leads_overall"),
    ("App leads in May 2026?",                                    "2026-05", "leads_app"),
    ("How many desktop website leads in April 2026?",             "2026-04", "leads_desktop"),
    ("Mobile website leads for May 2026",                         "2026-05", "leads_mobile"),
    ("Leads from other channels in May 2026?",                    "2026-05", "leads_others"),
    ("Total leads in July 2026?",                                 "2026-07", "leads_overall"),  # MTD case
    # orders
    ("How many orders were booked in May 2026?",                  "2026-05", "orders_overall"),
    ("Orders from the app in May 2026?",                          "2026-05", "orders_app"),
    ("Desktop website orders in April 2026?",                     "2026-04", "orders_desktop"),
    ("mweb orders in May 2026?",                                  "2026-05", "orders_mobile"),
    ("Orders from other channels in April 2026?",                 "2026-04", "orders_others"),
    ("Bookings in July 2026?",                                    "2026-07", "orders_overall"),  # MTD case
    # derived
    ("What was the conversion rate in May 2026?",                 "2026-05", "conversion_overall"),
    ("App conversion rate in May 2026?",                          "2026-05", "conversion_app"),
    ("Desktop conversion in April 2026?",                         "2026-04", "conversion_desktop"),
    ("What share of app orders did we have in May 2026?",         "2026-05", "pct_orders_app"),
    ("Website order share in May 2026?",                          "2026-05", "pct_orders_website"),
    ("Others order share in May 2026?",                           "2026-05", "pct_orders_others"),
    # tpo
    ("What was TPO in May 2026?",                                 "2026-05", "tpo_overall"),
    ("Tickets per order in May 2026?",                            "2026-05", "tpo_overall"),
    ("Vendor raised TPO in May 2026?",                            "2026-05", "tpo_vendor_raised"),
    ("Pre-trip TPO in April 2026?",                               "2026-04", "tpo_pre_trip"),
    ("How many orders in the TPO base in May 2026?",              "2026-05", "orders_base"),
    ("TPO for cancelled orders in May 2026?",                     "2026-05", "tpo_cancelled"),
]

# (question/metric, month, kind, expected refusal substring)
REFUSALS = [
    ("City-wise leads in Bangalore in May 2026?",  "2026-05", "question", "city"),
    ("Weekly orders trend for May 2026?",          "2026-05", "question", "weekly"),
    ("median tickets per order in May 2026?",      "2026-05", "question", "median"),
    ("Vendor wise TPO in May 2026?",               "2026-05", "question", "vendor"),
    ("ota_pct",                                    "2026-05", "metric_blocked", "blocked"),
    ("p80_trip_duration_mins",                     "2026-05", "metric_not_built", "not in the catalog"),
    ("tpo_overall",                                "2027-01", "future_month", "future"),
]


def check_sql(sql: str, month: str) -> list[str]:
    problems = []
    try:
        sqlgen.assert_read_only(sql)
    except ValueError as e:
        problems.append(f"read-only check failed: {e}")
    ms, msp = sqlgen.month_bounds(month)
    if f"'{ms}'" not in sql or f"'{msp}'" not in sql:
        problems.append("window months not substituted")
    tables = set(re.findall(r"PROD_CURATED\.[A-Za-z_]+\.[A-Za-z_]+", sql))
    unexpected = tables - EXPECTED_TABLES
    if unexpected:
        problems.append(f"unexpected tables: {unexpected}")
    if "NEW_INITIATIVE_ANALYTICS" in sql:
        problems.append("references the physical staging schema — must use inlined CTEs")
    return problems


def main():
    OUT.mkdir(exist_ok=True)
    lines = [f"# Dry-run test report — {date.today().isoformat()}", ""]
    passed = failed = 0

    lines.append("## Answerable questions (resolution + SQL render)\n")
    for q, month, expect in ANSWERABLE:
        got, why = resolve(q)
        problems = []
        if got != expect:
            problems.append(f"resolved to {got!r} (reason: {why}), expected {expect!r}")
        else:
            section = METRICS[got]["section"]
            sql = sqlgen.render(section, month)
            problems += check_sql(sql, month)
            mtd = sqlgen.is_month_in_progress(month)
            if month == date.today().strftime("%Y-%m") and not mtd:
                problems.append("MTD flag missing for current month")
        status = "PASS" if not problems else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        mtd_note = "  [MTD-labeled]" if sqlgen.is_month_in_progress(month) else ""
        lines.append(f"- **{status}** `{expect}` {month}{mtd_note} — \"{q}\""
                     + (f"  ⚠ {problems}" if problems else ""))

    lines.append("\n## Refusal cases (must NOT answer)\n")
    for q, month, kind, expect_sub in REFUSALS:
        ok, detail = False, ""
        if kind == "question":
            got, why = resolve(q)
            ok = got is None and (expect_sub in (why or ""))
            detail = f"resolver said: {why!r}" if got is None else f"WRONGLY resolved to {got}"
        elif kind == "metric_blocked":
            try:
                s = SECTIONS["ota"]
                ok = (not s["built"]) and s["readiness"] == "blocked"
                detail = f"ota readiness={s['readiness']}, built={s['built']}"
            except KeyError:
                detail = "ota section missing"
        elif kind == "metric_not_built":
            ok = q not in METRICS and not SECTIONS["p80_durations"]["built"]
            detail = "p80 metric ids not present in v0 registry; section marked not_built"
        elif kind == "future_month":
            ok = sqlgen.is_month_in_future(month)
            detail = f"{month} correctly detected as future"
        status = "PASS" if ok else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        lines.append(f"- **{status}** [{kind}] \"{q}\" ({month}) — {detail}")

    lines.append(f"\n## Summary: {passed} passed, {failed} failed")
    report = "\n".join(lines)
    (OUT / "dry_run_report.md").write_text(report)

    # Also render one full SQL per section for owner review (the exact queries
    # that would run in the execution round).
    for section in ("leads", "orders", "derived", "tpo"):
        (OUT / f"rendered_{section}_2026-05.sql").write_text(sqlgen.render(section, "2026-05"))

    print(report)
    print(f"\nRendered SQL for owner review written to {OUT}/rendered_*_2026-05.sql")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
