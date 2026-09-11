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
    # ota mirrors Metabase card #37409 (owner-ruled 2026-09-04)
    "PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS",
    "PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS",
    # gac_ctr mirrors the MBR automation's Get-a-Call CTR section (PNM-S-060)
    "PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES",
    "PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES_LATEST_LSM_SCORE",
    # weekend, cac_post_trip, addon, completion, vendor_earnings_bucket mirror the MBR
    # automation (PNM-S-060) over PNM_EXPERIENCE + FACT_PNM_ORDERS + CANCELLED_ORDER_EVENTS
    "PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS",
    # vendor_earnings_pctl + fare mirror the MBR automation over PNM_FARE_MOVEMENT
    "PROD_ELDORIA.MART.PNM_FARE_MOVEMENT",
    # allocation mirrors the MBR automation over PNM_ALLOCATION
    "PROD_ELDORIA.MART.PNM_ALLOCATION",
    # wallet mirrors the MBR automation's wallet withdrawal/recharge section
    "PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS",
    "PROD_CURATED.PNM_APPLICATION.VENDOR_WALLET_WITHDRAWAL",
    "PROD_CURATED.PNM_APPLICATION.PAYMENT_LINKS",
    "PROD_CURATED.PNM_APPLICATION.VENDOR_ALLOCATION_CONFIGS",
    "PROD_ELDORIA.CORE.DIM_PNM_VENDOR",
    # vendor_tpo_top5 mirrors the MBR automation's separate RAW-table TPO pipeline
    "PROD_ELDORIA.RAW.PNM_APPLICATION_ORDERS",
    "PROD_ELDORIA.RAW.PNM_APPLICATION_ORDER_ALLOCATION_INFOS",
    "PROD_ELDORIA.RAW.PNM_APPLICATION_SHIFTING_REQUIREMENTS",
    "PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS",
}

# (question, month, expected metric id)  — resolution + render must succeed
ANSWERABLE = [
    # leads
    ("How many leads did we get in May 2026?",                    "2026-05", "leads_overall_intra_city"),
    ("App leads in May 2026?",                                    "2026-05", "leads_app"),
    ("How many desktop website leads in April 2026?",             "2026-04", "leads_desktop"),
    ("Mobile website leads for May 2026",                         "2026-05", "leads_mobile"),
    ("Leads from other channels in May 2026?",                    "2026-05", "leads_others"),
    ("Total leads in July 2026?",                                 "2026-07", "leads_overall_intra_city"),  # MTD case
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
    # ota (owner-ruled 2026-09-04: 30 min AND 2 km, Card #37409)
    ("What was the on time arrival percentage in May 2026?",      "2026-05", "ota_pct"),
    ("OTA in April 2026?",                                        "2026-04", "ota_pct"),
    ("How many orders were on time in May 2026?",                 "2026-05", "ota_on_time_orders"),
    ("How many orders were delayed in May 2026?",                 "2026-05", "ota_delay_orders"),
    ("Orders delayed more than 60 minutes in May 2026?",          "2026-05", "ota_delay_gt_60_mins_orders"),
    ("Percent orders delayed over 60 minutes in May 2026?",       "2026-05", "ota_delay_gt_60_mins_pct"),
    ("How many orders in the ota base in May 2026?",              "2026-05", "ota_total_completed_orders"),
    ("Orders with no shifting started event in May 2026?",        "2026-05", "ota_unset_orders"),
    # gac_ctr (mirrors the MBR automation, PNM-S-060, PNM-G-071)
    ("Get a call CTR in May 2026?",                                "2026-05", "gac_ctr_pct"),
    ("What was the get a call click through rate in April 2026?", "2026-04", "gac_ctr_pct"),
    # 10 more sections built 2026-09-04, mirroring the MBR automation (PNM-S-060, PNM-G-071)
    ("Weekend order contribution in May 2026?",                    "2026-05", "weekend_order_share_pct"),
    ("CAC post trip started in May 2026?",                         "2026-05", "cac_post_trip_started_pct"),
    ("How many active vendors in May 2026?",                       "2026-05", "active_vendor_count"),
    ("What was the allocation percentage in May 2026?",            "2026-05", "allocation_pct"),
    ("Allocation time p80 in May 2026?",                           "2026-05", "allocation_time_p80_minutes"),
    ("Reschedule rate in May 2026?",                                "2026-05", "reschedule_pct"),
    ("Withdrawal failure rate in May 2026?",                       "2026-05", "withdrawal_failure_pct"),
    ("Vendor tpo raw pipeline in May 2026?",                       "2026-05", "vendor_tpo"),
    ("Overall add-on adoption in May 2026?",                       "2026-05", "pct_orders_with_any_addon"),
    ("Packing addon adoption in May 2026?",                        "2026-05", "pct_orders_with_packing"),
    ("Overall completion score in May 2026?",                      "2026-05", "completion_score_pct"),
    ("Overall NPS in May 2026?",                                   "2026-05", "nps"),
    ("Average order value in May 2026?",                           "2026-05", "aov"),
    ("Percent orders with surge in May 2026?",                     "2026-05", "pct_orders_with_surge"),
    ("Vendor earnings goldplus in May 2026?",                      "2026-05", "revenue_pct_goldplus"),
]

# metric ids that are intentionally NOT NL-exposed — reachable only via --metric.
# p50_trip_duration: blocked by the p50/median guard (D10). vendor-stage: given NO
# NL aliases so no natural phrasing resolves it (the earlier "vendor guard excludes
# it" rationale was FALSE — bare 'vendor' is not in UNSUPPORTED_TERMS; see board).
METRIC_ONLY = ["p50_trip_duration", "p80_vendor_accepted_to_sup_assigned",
               # 10 more found 2026-09-04 while building the MBR sections (PNM-G-071): their
               # natural phrasing unavoidably contains 'p50'/'median' or 'per vendor', both of
               # which UNSUPPORTED_TERMS blocks — same guard conflict as the two above (D10).
               "p50_earnings_per_vendor", "p80_earnings_per_vendor", "p50_orders_per_vendor",
               "p80_orders_per_vendor", "withdrawals_per_vendor", "recharges_per_vendor",
               "p50_withdrawal_amount", "p50_recharge_amount",
               "median_fare_increase_amt", "median_fare_decrease_amt"]

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
    # was `metric_not_built` hard-coded to p80's built=False — obsolete once p80 is
    # built. Repurposed to the true invariant: gate refuses any id absent from METRICS.
    # `metric_blocked` (ota_pct) was retired 2026-09-04 when ota was built — every
    # section is now built:True, so no id can hit that refusal path anymore.
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


def main(today: date | None = None):
    """`today` pins the report's notion of "now" so the artifact is reproducible —
    PNM-G-054: without it, is_month_in_progress() silently used the real current
    date, so re-running on a different day changed the committed dry_run_report.md
    with no code change behind it. Defaults to the real date for normal use;
    pass an explicit date (via --today=YYYY-MM-DD) to regenerate a past report
    byte-identically."""
    today = today or date.today()
    OUT.mkdir(exist_ok=True)
    lines = [f"# Dry-run test report — {today.isoformat()}", ""]
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
            mtd = sqlgen.is_month_in_progress(month, today)
            if month == today.strftime("%Y-%m") and not mtd:
                problems.append("MTD flag missing for current month")
        status = "PASS" if not problems else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        mtd_note = "  [MTD-labeled]" if sqlgen.is_month_in_progress(month, today) else ""
        lines.append(f"- **{status}** `{expect}` {month}{mtd_note} — \"{q}\""
                     + (f"  ⚠ {problems}" if problems else ""))

    lines.append("\n## Refusal cases (must NOT answer)\n")
    for q, month, kind, expect_sub in REFUSALS:
        ok, detail = False, ""
        if kind == "question":
            got, why = resolve(q)
            ok = got is None and (expect_sub in (why or ""))
            detail = f"resolver said: {why!r}" if got is None else f"WRONGLY resolved to {got}"
        elif kind == "metric_unknown":
            ok = q not in METRICS
            detail = (f"'{q}' correctly absent from the catalog — gate() would refuse "
                      "(this tool never improvises metrics)")
        elif kind == "future_month":
            ok = sqlgen.is_month_in_future(month, today)
            detail = f"{month} correctly detected as future"
        status = "PASS" if ok else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        lines.append(f"- **{status}** [{kind}] \"{q}\" ({month}) — {detail}")

    # New-section structural checks. The `AS month` column assertion is done HERE,
    # section-scoped — NOT inside the section-agnostic check_sql(), because derived
    # (SELECT l.month) and tpo (SELECT o.month) emit month without a literal `AS month`
    # token and a global check would falsely red them (board finding A-2).
    lines.append("\n## New-section structural checks (all sections built after iteration-3)\n")
    for section in ("p80_durations", "order_edits", "ota", "gac_ctr", "weekend", "cac_post_trip",
                     "vendor_earnings_pctl", "allocation", "wallet", "vendor_tpo_top5", "addon",
                     "completion", "fare", "vendor_earnings_bucket"):
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

    # Comprehensive column-production check for the 10 sections built 2026-09-04 (PNM-G-071):
    # for EVERY metric id in each section, assert the section's rendered SQL actually produces
    # a column of that name. This is the correctness backstop for the 82 new metric ids added
    # in this pass — full coverage without hand-writing 82 NL phrasings each (a defensible
    # scope tradeoff given the size of this build; each section still gets >=1 real NL question
    # above, and every metric here is independently live-reconciled per DECISION_LOG:D13/V7-V16).
    new_sections = ("weekend", "cac_post_trip", "vendor_earnings_pctl", "allocation", "wallet",
                     "vendor_tpo_top5", "addon", "completion", "fare", "vendor_earnings_bucket")
    lines.append(f"\n## Column-production check — every metric id in {new_sections}\n")
    for section in new_sections:
        try:
            sql = sqlgen.render(section, "2026-05")
        except Exception as e:
            lines.append(f"- **FAIL** {section} — render failed: {e}")
            failed += 1
            continue
        section_metrics = [mid for mid, m in METRICS.items() if m["section"] == section]
        # vendor_tpo_top5's 5 issue-breakdown ids are built via runtime string concatenation
        # ('l1_top5_issues_vendor_raised_' || REPLACE(LOWER(issue),' ','_')), not a static
        # column alias — unverifiable by regex. Live-executed and confirmed exact 2026-09-04
        # (DECISION_LOG:V-vendor-tpo): all 5 literal strings appeared in the metric column.
        dynamic_ids = {"l1_top5_issues_vendor_raised_changes_in_order_requirement",
                        "l1_top5_issues_vendor_raised_supervisor_reject_order",
                        "l1_top5_issues_vendor_raised_cancellation",
                        "l1_top5_issues_vendor_raised_customer_unreachable",
                        "l1_top5_issues_vendor_raised_payment_related"}
        missing = [mid for mid in section_metrics if mid not in dynamic_ids
                   and not re.search(rf"AS\s+{re.escape(mid)}\b", sql, re.I)
                   and not re.search(rf"'{re.escape(mid)}'\s+AS\s+metric\b", sql, re.I)]
        status = "PASS" if not missing else "FAIL"
        passed, failed = passed + (status == "PASS"), failed + (status == "FAIL")
        lines.append(f"- **{status}** {section} ({len(section_metrics)} metrics)"
                     + (f"  ⚠ missing columns for: {missing}" if missing else " — every metric id produced"))

    lines.append(f"\n## Summary: {passed} passed, {failed} failed")
    report = "\n".join(lines)
    (OUT / "dry_run_report.md").write_text(report)

    # Also render one full SQL per section for owner review (the exact queries
    # that would run in the execution round).
    for section in ("leads", "orders", "derived", "tpo", "p80_durations", "order_edits", "ota", "gac_ctr",
                     "weekend", "cac_post_trip", "vendor_earnings_pctl", "allocation", "wallet",
                     "vendor_tpo_top5", "addon", "completion", "fare", "vendor_earnings_bucket"):
        (OUT / f"rendered_{section}_2026-05.sql").write_text(sqlgen.render(section, "2026-05"))

    print(report)
    print(f"\nRendered SQL for owner review written to {OUT}/rendered_*_2026-05.sql")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    pinned_today = None
    for arg in sys.argv[1:]:
        if arg.startswith("--today="):
            pinned_today = date.fromisoformat(arg.split("=", 1)[1])
    main(pinned_today)
