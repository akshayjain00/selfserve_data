"""
PnM Self-Serve NL Query Layer — CLI (v0)
=========================================
Answers ONE catalog metric question at a time. Read-only. Dry-run by default.

Usage:
    python ask.py --list
    python ask.py --metric tpo_overall --month 2026-05              # DRY RUN: prints the exact SQL + footer, executes nothing
    python ask.py --metric tpo_overall --month 2026-05 --execute    # runs the single read-only SELECT (needs SF_* env vars)
    python ask.py --question "tickets per order in may" --month 2026-05
    python ask.py --metric orders_overall --month 2026-05 --trend week   # one row per week in May
    python ask.py --question "weekly orders trend for May 2026?"          # same, via NL

Guardrails (enforced here, not by convention):
    * only metric ids present in metrics_registry.METRICS can be queried
    * only sections marked built can be queried; blocked/not_built refuse with the reason
    * every built section except `fare` answers month, week, OR a single day —
      day/week REPLACE the month filter using the same query, just a narrower
      grain (PNM-G-070 close-out, DECISION_LOG:D25); `fare` is month-only, one
      of its metric halves is sourced from a pre-aggregated monthly column
    * every built section except `fare` also answers a TREND — one row per
      week/day inside a month, same query widened to the whole month and
      grouped by grain instead of narrowed to one period (PNM-G-070 trend
      close-out, DECISION_LOG:D27); `--trend week`/`--trend day` or NL
      phrasing like "weekly orders trend for May 2026"
    * a city/week/day/trend asked of a section with no validated cut does NOT
      refuse outright — it falls back to that section's plain monthly figure
      and prints a "⚠ CAVEAT" naming the Metabase dashboard that has the real
      cut today, provided a month is available to fall back to (DECISION_LOG:D22)
    * SQL is fully rendered before anything touches a connection — what you see
      is byte-for-byte what runs; sqlgen.assert_read_only rejects non-SELECT
    * Snowflake credentials are read only inside --execute (lazy import)
    * every executed answer is appended to answers_log/answers.jsonl
"""

import argparse
import json
import os
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

from metrics_registry import SECTIONS, METRICS, CONFIG_WIDE_FLAGS, resolve
import sqlgen

LOG_DIR = Path(__file__).parent / "answers_log"


def refuse(msg: str, code: int = 2):
    print(f"REFUSED: {msg}")
    sys.exit(code)


def footer(section_name: str, month: str, executed: bool, week_start: str | None = None,
           day: str | None = None) -> str:
    s = SECTIONS[section_name]
    lines = []
    # Source/Computed provenance is per-section (a section may set source_desc /
    # computed_desc); the defaults describe the original leads/orders/derived/tpo
    # mirrors, so those four are unchanged. New sections (p80_durations, order_edits)
    # read PROD_ELDORIA.MART.PNM_EXPERIENCE and MUST override, else the footer would
    # misattribute their source (board finding B-2).
    default_source = (f"PnM MBR catalog §{section_name} — mirrors the owner's live-validated MBR "
                      f"automation (leads/orders/derived → LEADS_CONVERSION_QUERY; tpo → TPO_TREND_QUERY / card #47576)")
    lines.append("Source: " + s.get("source_desc", default_source))
    lines.append(f"Month basis: {s['month_basis']}")
    lines.append(f"Base population: {s['base_population']}")
    if executed:
        default_computed = ("live at query time from the governed sources — PROD_ELDORIA core/mart "
                            "(leads/orders/derived) and PROD_CURATED raw (tpo); reconcile against the MBR note / Notion Demand DB")
        lines.append("Computed: " + s.get("computed_desc", default_computed))
    if day:
        pass  # a single day is unambiguous — never MTD, never spans anything
    elif week_start:
        # A week-scoped answer is never "MTD" in the usual sense — it's a fixed
        # 7-day window, past or present.
        if sqlgen.week_spans_two_months(week_start):
            week_end = (date.fromisoformat(week_start) + timedelta(days=6)).isoformat()
            lines.append(f"⚠ WEEK SPANS TWO MONTHS: {week_start} through {week_end} "
                         "crosses a calendar-month boundary — this total includes both months in full, not split")
    elif sqlgen.is_month_in_progress(month):
        lines.append(f"⚠ MONTH IN PROGRESS: this is an MTD value as of {date.today().isoformat()} — "
                     "not a final monthly number")
    lines.append(f"Readiness: {s['readiness'].upper()}"
                 + ("" if s["readiness"] == "stakeholder_ready"
                    else " — do not quote to stakeholders without owner approval"))
    flags = list(s["verify_flags"]) + CONFIG_WIDE_FLAGS
    if flags:
        lines.append("⚠ Open flags on this section (verbatim, unresolved):")
        lines += [f"    - {f}" for f in flags]
    if s["quirks"]:
        lines.append("Known quirks (replicated from the pipeline, disclosed not fixed):")
        lines += [f"    - {q}" for q in s["quirks"]]
    if s.get("evidence"):
        lines.append("Evidence on open flags (owner decision pending):")
        lines += [f"    - {e}" for e in s["evidence"]]
    return "\n".join(lines)


def gate(metric_id: str, month: str | None, city: str | None = None, week_start: str | None = None,
         day: str | None = None):
    """Validate metric + (month | week_start | day) and city/week/day support.

    Returns (spec, section_name, effective_city, effective_week_start, effective_day,
    caveats, None) on success, or (None, None, None, None, None, [], reason) on
    refusal — mirrors resolve()'s return-not-exit contract so it's directly
    testable. Exactly one of month/week_start/day drives the date range — day
    takes precedence over week_start over month (PNM-G-070/DECISION_LOG:D25),
    same convention as sqlgen.period_filter().

    A city/week/day requested against a section with no validated cut is NOT a
    hard refusal on its own (`DECISION_LOG:D22`): it falls back to the section's
    plain PnM-wide monthly figure (dropping the unsupported filter), carrying a
    caveat that names the section's `metabase_fallback` dashboard — provided a
    month is available to fall back to. A week/day request with no month to fall
    back to still refuses outright: there is nothing left to compute."""
    if metric_id not in METRICS:
        return None, None, None, None, None, [], (f"'{metric_id}' is not in the catalog. Run --list to see "
                                                    "the menu — this tool never improvises metrics.")
    spec = METRICS[metric_id]
    section_name = spec["section"]
    section = SECTIONS[section_name]
    if not section["built"]:
        reason = section.get("blocked_reason", "section not built in this iteration")
        return None, None, None, None, None, [], f"section '{section_name}' is {section['readiness']}: {reason}"

    caveats = []
    effective_city = city
    effective_week = week_start
    effective_day = day

    if city and not section.get("supports_city"):
        fallback = section.get("metabase_fallback")
        hint = f" — for a validated city cut today, see {fallback}" if fallback else ""
        caveats.append(f"'{city}' was requested, but section '{section_name}' has no validated city "
                        f"cut yet (PNM-G-070) — showing the PnM-wide total instead{hint}")
        effective_city = None

    for label, value, flag, attr in (("week", week_start, "supports_week", "effective_week"),
                                      ("day", day, "supports_day", "effective_day")):
        if value and not section.get(flag):
            fallback = section.get("metabase_fallback")
            if month:
                hint = f" — for a validated {label} cut today, see {fallback}" if fallback else ""
                caveats.append(f"the {label} of {value} was requested, but section '{section_name}' has "
                                f"no validated {label} cut yet (PNM-G-070) — showing {month} instead{hint}")
                if attr == "effective_week":
                    effective_week = None
                else:
                    effective_day = None
            else:
                hint = f" — see {fallback} for a {label} cut today" if fallback else ""
                return None, None, None, None, None, [], (f"section '{section_name}' has no validated "
                                                            f"{label} cut yet (PNM-G-070), and no --month "
                                                            f"was given to fall back to{hint}")

    if effective_day:
        try:
            sqlgen.validate_day(effective_day)
        except ValueError as e:
            return None, None, None, None, None, [], str(e)
        if sqlgen.is_day_in_future(effective_day):
            return None, None, None, None, None, [], f"{effective_day} is in the future"
    elif effective_week:
        try:
            sqlgen.validate_week_start(effective_week)
        except ValueError as e:
            return None, None, None, None, None, [], str(e)
        if sqlgen.is_week_in_future(effective_week):
            return None, None, None, None, None, [], f"the week of {effective_week} is in the future"
    else:
        if not month:
            return None, None, None, None, None, [], "need --month, --week, or --day"
        try:
            sqlgen.month_bounds(month)
        except ValueError as e:
            return None, None, None, None, None, [], str(e)
        if sqlgen.is_month_in_future(month):
            return None, None, None, None, None, [], f"{month} is in the future"
    return spec, section_name, effective_city, effective_week, effective_day, caveats, None


def gate_trend(metric_id: str, month: str | None, grain: str, city: str | None = None):
    """Validates a TREND request — PNM-G-070 trend close-out, DECISION_LOG:D27.
    A trend is a breakdown OF a month into `grain` ('week'/'day') buckets, so
    --month is always required (there is no week_start/day fallback the way
    the single-period gate() has, a trend has nothing else to be relative to).

    Returns (spec, section_name, effective_city, caveats, supported, reason).
    `supported` is False when the section has no validated `grain` cut at all
    (reuses the same supports_week/supports_day flags as the single-period
    path — the underlying capability is identical, TREND_SQL's membership
    matches sqlgen._PERIOD_CAPABLE_SQL's exactly) — the caller falls back to
    the plain single-row monthly answer via gate() instead of refusing,
    same graceful-fallback philosophy as D22."""
    if metric_id not in METRICS:
        return None, None, None, [], True, (f"'{metric_id}' is not in the catalog. Run --list to see "
                                              "the menu — this tool never improvises metrics.")
    spec = METRICS[metric_id]
    section_name = spec["section"]
    section = SECTIONS[section_name]
    if not section["built"]:
        reason = section.get("blocked_reason", "section not built in this iteration")
        return None, None, None, [], True, f"section '{section_name}' is {section['readiness']}: {reason}"
    if not month:
        return None, None, None, [], True, "need --month for a trend — it breaks a month down, nothing to break down without one"
    try:
        sqlgen.month_bounds(month)
    except ValueError as e:
        return None, None, None, [], True, str(e)
    if sqlgen.is_month_in_future(month):
        return None, None, None, [], True, f"{month} is in the future"

    caveats = []
    effective_city = city
    if city and not section.get("supports_city"):
        fallback = section.get("metabase_fallback")
        hint = f" — for a validated city cut today, see {fallback}" if fallback else ""
        caveats.append(f"'{city}' was requested, but section '{section_name}' has no validated city "
                        f"cut yet (PNM-G-070) — showing the PnM-wide total instead{hint}")
        effective_city = None

    flag = "supports_week" if grain == "week" else "supports_day"
    if not section.get(flag):
        return spec, section_name, effective_city, caveats, False, None
    return spec, section_name, effective_city, caveats, True, None


def compute_value(metric_id: str, row: dict):
    """Extract or derive the metric value from the section result row.
    Derived ratios: aggregate numerator ÷ denominator — never averaged ratios."""
    spec = METRICS[metric_id]
    if spec["source"] == "sql":
        return row.get(metric_id)
    num_cols = spec["numerator"] if isinstance(spec["numerator"], tuple) else (spec["numerator"],)
    num = sum(float(row[c]) for c in num_cols)
    den = float(row[spec["denominator"]])
    if den == 0:
        return None
    return round(spec["scale"] * num / den, 2)


def execute(sql: str) -> list[dict]:
    import snowflake.connector  # lazy: only --execute needs it
    conn = snowflake.connector.connect(
        account=os.environ["SF_ACCOUNT"],
        user=os.environ["SF_USER"],
        password=os.environ["SF_PASSWORD"],
        warehouse=os.environ.get("SF_WAREHOUSE", "COMPUTE_WH"),
        database=os.environ.get("SF_DATABASE", "PROD_CURATED"),
        schema=os.environ.get("SF_SCHEMA", "pnm_application"),
        role=os.environ.get("SF_ROLE", ""),
    )
    try:
        cur = conn.cursor()
        cur.execute(sql)
        cols = [d[0].lower() for d in cur.description]
        rows = [dict(zip(cols, r)) for r in cur.fetchall()]
        cur.close()
        return rows
    finally:
        conn.close()


def log_answer(payload: dict):
    LOG_DIR.mkdir(exist_ok=True)
    with open(LOG_DIR / "answers.jsonl", "a") as f:
        f.write(json.dumps(payload, default=str) + "\n")


def cmd_list():
    print(f"{'metric id':<28} {'section':<14} {'unit':<14} readiness")
    print("-" * 80)
    for mid, spec in METRICS.items():
        s = SECTIONS[spec["section"]]
        print(f"{mid:<28} {spec['section']:<14} {spec['unit']:<14} {s['readiness']}")
    print("\nSections not queryable in v0:")
    for name, s in SECTIONS.items():
        if not s["built"]:
            print(f"  {name}: {s['readiness']}"
                  + (f" — {s['blocked_reason']}" if s.get("blocked_reason") else ""))


def main():
    p = argparse.ArgumentParser(description="PnM self-serve metric query (v0, read-only, dry-run default)")
    p.add_argument("--list", action="store_true", help="show the catalog menu")
    p.add_argument("--metric", help="metric id from the registry")
    p.add_argument("--question", help="plain-English question (deterministic alias match only)")
    p.add_argument("--month", help="YYYY-MM")
    p.add_argument("--city", help="a single named city — validated cut only on some sections (PNM-G-070)")
    p.add_argument("--week", help="Monday-start date YYYY-MM-DD for a single specific week — "
                                  "overrides --month; not supported by 'fare' (PNM-G-070)")
    p.add_argument("--day", help="YYYY-MM-DD for a single specific day — overrides --month/--week; "
                                 "not supported by 'fare' (PNM-G-070/DECISION_LOG:D25)")
    p.add_argument("--trend", choices=["week", "day"],
                   help="return one row per week/day inside --month instead of one monthly row — "
                        "not supported by 'fare' (PNM-G-070 trend close-out, DECISION_LOG:D27)")
    p.add_argument("--execute", action="store_true",
                   help="actually run the SELECT (default is dry-run: print SQL and exit)")
    args = p.parse_args()

    if args.list:
        cmd_list()
        return

    metric_id = args.metric
    city, week_start, day, trend = args.city, args.week, args.day, args.trend
    if not metric_id and args.question:
        metric_id, resolved_city, resolved_week, resolved_day, resolved_trend, why = resolve(args.question)
        if metric_id is None:
            refuse(f"cannot resolve question: {why}")
        print(f"[resolved question → metric id: {metric_id}]\n")
        city = city or resolved_city
        week_start = week_start or resolved_week
        day = day or resolved_day
        trend = trend or resolved_trend
    if not metric_id or (not args.month and not week_start and not day and not trend):
        p.error("need --metric (or --question) and --month (or --week/--day/--trend), or --list")

    gated = False
    if trend:
        spec, section_name, city, caveats, supported, why = gate_trend(metric_id, args.month, trend, city=city)
        if spec is None:
            refuse(why)
        if not supported:
            fallback = SECTIONS[section_name].get("metabase_fallback")
            hint = f" — for a {trend}ly trend today, see {fallback}" if fallback else ""
            trend_caveat = (f"a {trend}ly trend was requested, but section '{section_name}' has no "
                             f"validated {trend} cut yet (PNM-G-070) — showing the plain month total "
                             f"instead{hint}")
            trend = None
            spec, section_name, city, week_start, day, caveats, why = gate(
                metric_id, args.month, city=city)
            if spec is None:
                refuse(why)
            caveats = [trend_caveat] + caveats
            gated = True
        else:
            week_start = day = None  # trend supersedes any stray --week/--day
            gated = True

    if not gated:
        spec, section_name, city, week_start, day, caveats, why = gate(
            metric_id, args.month, city=city, week_start=week_start, day=day)
        if spec is None:
            refuse(why)
    sql = (sqlgen.render_trend(section_name, args.month, trend, city=city) if trend
           else sqlgen.render(section_name, args.month, city=city, week_start=week_start, day=day))

    print(f"Metric:  {metric_id} — {spec['definition']}")
    if trend:
        print(f"Trend:   one row per {trend} inside {args.month}")
    elif day:
        print(f"Day:     {day}")
    elif week_start:
        label = f"Week of {week_start} through {(date.fromisoformat(week_start) + timedelta(days=6)).isoformat()}"
        if sqlgen.week_spans_two_months(week_start):
            label += " — spans two calendar months"
        print(label)
    else:
        print(f"Month:   {args.month}")
    if city:
        print(f"City:    {city}")
    print(f"Section: {section_name}")
    for c in caveats:
        print(f"⚠ CAVEAT: {c}")
    print()

    if not args.execute:
        print("── DRY RUN — the following SQL was NOT executed ──────────────────────")
        print(sql)
        print("──────────────────────────────────────────────────────────────────────")
        print(footer(section_name, args.month, executed=False, week_start=week_start, day=day))
        print("\nTo run it: add --execute (requires SF_* env vars; single read-only SELECT).")
        return

    rows = execute(sql)

    if trend:
        # Multi-row: one line per period, ordered as the query already ordered them
        # (ORDER BY period, every *_trend_sql builder). Never picks a single row —
        # that's the whole point of a trend request.
        if not rows:
            print(f"No rows returned for {args.month}.")
            print(footer(section_name, args.month, executed=True))
            return
        unit = spec["unit"]
        scope = f" in {city}" if city else ""
        print(f"TREND: {metric_id}{scope}, {trend}ly, {args.month}")
        for row in rows:
            value = compute_value(metric_id, row)
            period_label = str(row["month"])[:10]
            extra = f"  (orders_base = {row.get('orders_base')})" if section_name == "tpo" else ""
            print(f"  {period_label}: {value} {unit}{extra}")
        print()
        print(footer(section_name, args.month, executed=True))

        log_answer({
            "ts": datetime.now().isoformat(),
            "metric": metric_id, "month": args.month, "city": city, "trend": trend,
            "rows": rows, "sql": sql,
            "readiness": SECTIONS[section_name]["readiness"],
            "caveats": caveats,
        })
        return

    expected_date = day or week_start or sqlgen.month_bounds(args.month)[0]
    row = next((r for r in rows if str(r["month"])[:10] == expected_date), None)
    if row is None:
        print(f"No data row for {expected_date}. Dates returned: "
              f"{[str(r['month'])[:10] for r in rows]}")
        print(footer(section_name, args.month, executed=True, week_start=week_start, day=day))
        return

    value = compute_value(metric_id, row)
    unit = spec["unit"]
    period = f"day {day}" if day else (f"week of {week_start}" if week_start else args.month)
    scope = f" in {city}" if city else ""
    print(f"ANSWER: {metric_id}{scope} for {period} = {value} {unit}")
    if section_name == "tpo":
        print(f"        (orders_base = {row.get('orders_base')})")
    if spec["source"] == "derived":
        print(f"        (from raw counts: {row})")
    print()
    print(footer(section_name, args.month, executed=True, week_start=week_start, day=day))

    log_answer({
        "ts": datetime.now().isoformat(),
        "metric": metric_id, "month": args.month, "city": city, "week_start": week_start, "day": day,
        "value": value, "row": row, "sql": sql,
        "readiness": SECTIONS[section_name]["readiness"],
        "caveats": caveats,
    })


if __name__ == "__main__":
    main()
