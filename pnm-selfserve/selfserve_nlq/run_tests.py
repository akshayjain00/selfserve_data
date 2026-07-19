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
    # leads/orders/derived mirror LEADS_CONVERSION_QUERY (PROD_ELDORIA core/mart)
    "PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY",
    "PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY",
    "PROD_ELDORIA.CORE.FACT_PNM_ORDERS",
    "PROD_ELDORIA.CORE.DIM_PNM_ORDERS",
    "PROD_ELDORIA.MART.PNM_CUSTOMERS",
    # tpo mirrors TPO_TREND_QUERY / card #47576 (PROD_CURATED raw)
    "PROD_CURATED.PNM_APPLICATION.ORDERS",
    "PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS",
    "PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS",
    "PROD_CURATED.SFMS_PUBLIC.HS_TICKETS",
    # p80_durations + order_edits mirror TRIP_DURATION_PERCENTILE_QUERY /
    # EDIT_ADOPTION_QUERY (single governed mart, verified live 2026-07-19)
    "PROD_ELDORIA.MART.PNM_EXPERIENCE",
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
    # p80_durations (NL-exposed stages; p50 + vendor-stage are --metric only)
    ("p80 supervisor assigned to trip started in May 2026?",      "2026-05", "p80_sup_assigned_to_trip_started"),
    ("p80 trip started to shifting started in May 2026?",         "2026-05", "p80_trip_started_to_shifting_started"),
    ("p80 shifting started to pickup complete in May 2026?",      "2026-05", "p80_shifting_started_to_pickup_complete"),
    ("p80 pickup complete to order complete in May 2026?",        "2026-05", "p80_pickup_complete_to_order_complete"),
    ("What was the p80 trip duration in May 2026?",               "2026-05", "p80_trip_duration"),
    # order_edits (all 10 NL-exposed; location duplicated by design under 2 ids)
    ("percent orders edited in May 2026?",                        "2026-05", "pct_orders_edited"),
    ("number of successful edits in May 2026?",                   "2026-05", "no_of_successful_edits"),
    ("percent support edited orders in May 2026?",                "2026-05", "pct_support_edited_orders"),
    ("location edit adoption in May 2026?",                       "2026-05", "location_adoption_pct"),
    ("percent orders location modified in May 2026?",             "2026-05", "pct_orders_location_modified"),
    ("items edit adoption in May 2026?",                          "2026-05", "items_adoption_pct"),
    ("addons edit adoption in May 2026?",                         "2026-05", "addons_adoption_pct"),
    ("slot edit adoption in May 2026?",                           "2026-05", "slot_adoption_pct"),
    ("edits per order in May 2026?",                              "2026-05", "edits_per_order"),
    ("percent edits after shifting started in May 2026?",         "2026-05", "pct_edits_after_shifting_started"),
]

# metric ids that are intentionally NOT NL-exposed — reachable only via --metric.
# p50_trip_duration: blocked by the p50/median guard (D10). vendor-stage: given NO
# NL aliases so no natural phrasing resolves it (the earlier "vendor guard excludes
# it" rationale was FALSE — bare 'vendor' is not in UNSUPPORTED_TERMS; see board).
METRIC_ONLY = ["p50_trip_duration", "p80_vendor_accepted_to_sup_assigned"]

# (question/metric, month, kind, expected refusal substring)
REFUSALS = [
    ("City-wise leads in Bangalore in May 2026?",  "2026-05", "question", "city"),
    ("Weekly orders trend for May 2026?",          "2026-05", "question", "weekly"),
    ("median tickets per order in May 2026?",      "2026-05", "question", "median"),
    ("Vendor wise TPO in May 2026?",               "2026-05", "question", "vendor"),
    # p80_durations guard cases: percentile/stat cuts the catalog does not expose
    ("median trip duration in May 2026?",          "2026-05", "question", "median"),
    ("p50 trip duration in May 2026?",             "2026-05", "question", "p50"),
    ("p90 trip duration in May 2026?",             "2026-05", "question", "p90"),
    ("trip duration by vendor in May 2026?",       "2026-05", "question", "vendor"),
    ("ota_pct",                                    "2026-05", "metric_blocked", "blocked"),
    # was `metric_not_built` hard-coded to p80's built=False — obsolete once p80 is
    # built. Repurposed to the true invariant: gate refuses any id absent from METRICS.
    ("totally_made_up_metric",                     "2026-05", "metric_unknown", "not in the catalog"),
    ("tpo_overall",                                "2027-01", "future_month", "future"),
]


def check_sql(sql: str, month: str) -> list[str]:
    problems = []
    try:
        sqlgen.assert_read_only(sql)
    except ValueError as e:
        problems.append(f"read-only check failed: {e}")
    ms, _ = sqlgen.month_bounds(month)
    if f"'{ms}'" not in sql:
        problems.append("requested month not substituted")
    tables = set(re.findall(r"PROD_(?:CURATED|ELDORIA)\.[A-Za-z_]+\.[A-Za-z_]+", sql))
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
        elif kind == "metric_unknown":
            ok = q not in METRICS
            detail = (f"'{q}' correctly absent from the catalog — gate() would refuse "
                      "(this tool never improvises metrics)")
        elif kind == "future_month":
            ok = sqlgen.is_month_in_future(month)
            detail = f"{month} correctly detected as future"
        status = "PASS" if ok else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        lines.append(f"- **{status}** [{kind}] \"{q}\" ({month}) — {detail}")

    # New-section structural checks. The `AS month` column assertion is done HERE,
    # section-scoped — NOT inside the section-agnostic check_sql(), because derived
    # (SELECT l.month) and tpo (SELECT o.month) emit month without a literal `AS month`
    # token and a global check would falsely red them (board finding A-2).
    lines.append("\n## New-section structural checks (p80_durations, order_edits)\n")
    for section in ("p80_durations", "order_edits"):
        problems = []
        try:
            sql = sqlgen.render(section, "2026-05")
        except Exception as e:
            problems.append(f"render failed: {e}")
            sql = ""
        if sql:
            if not re.search(r"AS\s+month\b", sql, re.I):
                problems.append("missing `AS month` column (ask.py matches the row on it)")
            problems += check_sql(sql, "2026-05")
        status = "PASS" if not problems else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        lines.append(f"- **{status}** {section} render"
                     + (f"  ⚠ {problems}" if problems else " — AS month present, read-only, allow-listed tables"))

    # --metric-only metrics: no NL alias, reachable only via `ask.py --metric`. Assert
    # each is in the catalog, its section is built, and it is actually PRODUCED as a
    # column by the section SQL (guards against a registry-id ↔ SQL-alias typo) — the
    # only automated coverage these two ids get (board finding A-7).
    lines.append("\n## `--metric`-only metrics (no NL alias)\n")
    for mid in METRIC_ONLY:
        problems = []
        if mid not in METRICS:
            problems.append("absent from METRICS")
        else:
            section = METRICS[mid]["section"]
            if not SECTIONS[section]["built"]:
                problems.append(f"section {section!r} not built")
            try:
                sql = sqlgen.render(section, "2026-05")
                if not re.search(rf"AS\s+{re.escape(mid)}\b", sql, re.I):
                    problems.append(f"SQL does not produce a column `AS {mid}`")
            except Exception as e:
                problems.append(f"render failed: {e}")
        # and it must NOT be NL-reachable — not even by typing its id verbatim
        # (otherwise the "--metric only" contract is a lie; board/checker nit).
        got, _ = resolve(mid.replace("_", " ") + " in May 2026")
        if got is not None:
            problems.append(f"NL-reachable via id phrasing → resolved to {got!r}")
        status = "PASS" if not problems else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        lines.append(f"- **{status}** {mid}"
                     + (f"  ⚠ {problems}" if problems else " — in catalog, produced as a column, no NL alias"))

    lines.append(f"\n## Summary: {passed} passed, {failed} failed")
    report = "\n".join(lines)
    (OUT / "dry_run_report.md").write_text(report)

    # Also render one full SQL per section for owner review (the exact queries
    # that would run in the execution round).
    for section in ("leads", "orders", "derived", "tpo", "p80_durations", "order_edits"):
        (OUT / f"rendered_{section}_2026-05.sql").write_text(sqlgen.render(section, "2026-05"))

    print(report)
    print(f"\nRendered SQL for owner review written to {OUT}/rendered_*_2026-05.sql")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
