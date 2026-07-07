"""
PnM Self-Serve NL Query Layer — CLI (v0)
=========================================
Answers ONE catalog metric question at a time. Read-only. Dry-run by default.

Usage:
    python ask.py --list
    python ask.py --metric tpo_overall --month 2026-05              # DRY RUN: prints the exact SQL + footer, executes nothing
    python ask.py --metric tpo_overall --month 2026-05 --execute    # runs the single read-only SELECT (needs SF_* env vars)
    python ask.py --question "tickets per order in may" --month 2026-05

Guardrails (enforced here, not by convention):
    * only metric ids present in metrics_registry.METRICS can be queried
    * only sections marked built can be queried; blocked/not_built refuse with the reason
    * SQL is fully rendered before anything touches a connection — what you see
      is byte-for-byte what runs; sqlgen.assert_read_only rejects non-SELECT
    * Snowflake credentials are read only inside --execute (lazy import)
    * every executed answer is appended to answers_log/answers.jsonl
"""

import argparse
import json
import os
import sys
from datetime import date, datetime
from pathlib import Path

from metrics_registry import SECTIONS, METRICS, CONFIG_WIDE_FLAGS, resolve
import sqlgen

LOG_DIR = Path(__file__).parent / "answers_log"


def refuse(msg: str, code: int = 2):
    print(f"REFUSED: {msg}")
    sys.exit(code)


def footer(section_name: str, month: str, executed: bool) -> str:
    s = SECTIONS[section_name]
    lines = []
    lines.append(f"Source: PnM MBR catalog §{section_name} — adapted bug-for-bug from queries.py "
                 f"(methodology: Metabase card #30311 + Notion MoM doc)")
    lines.append(f"Month basis: {s['month_basis']}")
    lines.append(f"Base population: {s['base_population']}")
    if executed:
        lines.append("Computed: live from PROD_CURATED.pnm_application at query time "
                     "(may differ from the locked MBR sheet, a frozen weekly snapshot)")
    if sqlgen.is_month_in_progress(month):
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


def gate(metric_id: str, month: str):
    """Validate metric + month; return (spec, section_name) or refuse."""
    if metric_id not in METRICS:
        refuse(f"'{metric_id}' is not in the catalog. Run --list to see the menu — "
               "this tool never improvises metrics.")
    spec = METRICS[metric_id]
    section = SECTIONS[spec["section"]]
    if not section["built"]:
        reason = section.get("blocked_reason", "section not built in this iteration")
        refuse(f"section '{spec['section']}' is {section['readiness']}: {reason}")
    try:
        sqlgen.month_bounds(month)
    except ValueError as e:
        refuse(str(e))
    if sqlgen.is_month_in_future(month):
        refuse(f"{month} is in the future")
    return spec, spec["section"]


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
    p.add_argument("--execute", action="store_true",
                   help="actually run the SELECT (default is dry-run: print SQL and exit)")
    args = p.parse_args()

    if args.list:
        cmd_list()
        return

    metric_id = args.metric
    if not metric_id and args.question:
        metric_id, why = resolve(args.question)
        if metric_id is None:
            refuse(f"cannot resolve question: {why}")
        print(f"[resolved question → metric id: {metric_id}]\n")
    if not metric_id or not args.month:
        p.error("need --metric (or --question) and --month, or --list")

    spec, section_name = gate(metric_id, args.month)
    sql = sqlgen.render(section_name, args.month)

    print(f"Metric:  {metric_id} — {spec['definition']}")
    print(f"Month:   {args.month}")
    print(f"Section: {section_name}\n")

    if not args.execute:
        print("── DRY RUN — the following SQL was NOT executed ──────────────────────")
        print(sql)
        print("──────────────────────────────────────────────────────────────────────")
        print(footer(section_name, args.month, executed=False))
        print("\nTo run it: add --execute (requires SF_* env vars; single read-only SELECT).")
        return

    rows = execute(sql)
    month_start, _ = sqlgen.month_bounds(args.month)
    row = next((r for r in rows if str(r["month"])[:10] == month_start), None)
    if row is None:
        print(f"No data row for {args.month}. Months returned: "
              f"{[str(r['month'])[:10] for r in rows]}")
        print(footer(section_name, args.month, executed=True))
        return

    value = compute_value(metric_id, row)
    unit = spec["unit"]
    print(f"ANSWER: {metric_id} for {args.month} = {value} {unit}")
    if section_name == "tpo":
        print(f"        (orders_base = {row.get('orders_base')})")
    if spec["source"] == "derived":
        print(f"        (from raw counts: {row})")
    print()
    print(footer(section_name, args.month, executed=True))

    log_answer({
        "ts": datetime.now().isoformat(),
        "metric": metric_id, "month": args.month,
        "value": value, "row": row, "sql": sql,
        "readiness": SECTIONS[section_name]["readiness"],
    })


if __name__ == "__main__":
    main()
