# ask.py
"""
PTL Self-Serve NL Query Layer — CLI (v0). Read-only. DRY-RUN by default.

    python ask.py --list
    python ask.py --metric total_fulfilment_pct --month 2026-04          # DRY RUN: prints SQL + footer
    python ask.py --question "what was fulfilment in april" --month 2026-04
    python ask.py --metric aov --month 2026-04 --execute                 # runs 1 SELECT (needs SF_* env + P1 done)

Guardrails (enforced, not by convention):
  * only ids in metrics_registry.METRICS resolve; everything else refuses (closed-world).
  * SQL is fully rendered before anything touches a connection; core.assert_read_only rejects non-SELECT.
  * --execute is BLOCKED while pre-work P1 (state-enum) is unconfirmed — the honest gate.
  * Snowflake creds read only inside --execute (lazy import), via a read-only role.
"""
import argparse, os, sys
from metrics_registry import (METRICS, SECTIONS, CONFIG_WIDE_FLAGS, STATE_ENUM_CONFIRMED,
                               OFFLINE_STATUS_CONFIRMED, DEFERRED)
import sqlgen
from core import assert_read_only, resolve, footer


def refuse(msg, code=2):
    print(f"REFUSED: {msg}"); sys.exit(code)


def cmd_list():
    print(f"{'metric id':<32}{'section':<15}{'lvl':<5}{'src':<11}{'both-bases':<11}readiness")
    print("-" * 92)
    for mid, m in METRICS.items():
        print(f"{mid:<32}{m.section:<15}{m.level:<5}{m.source:<11}{('yes' if m.both_bases else 'no'):<11}{SECTIONS[m.section]['readiness']}")
    print("\nconfig-wide flags:")
    for f in CONFIG_WIDE_FLAGS: print(f"  ⚠ {f}")
    print("\ndeferred from v1:")
    for k, v in DEFERRED.items(): print(f"  · {k}: {v}")


def compute(rows_by_basis, plan):
    """aggregate-then-ratio; divide-by-zero -> None. Returns {basis: value}."""
    kind = plan[1]
    out = {}
    for basis, row in rows_by_basis.items():
        if kind == "ratio":
            num_c, den_c, scale = plan[2]
            den = row.get(den_c)
            out[basis] = None if not den else round(scale * row.get(num_c, 0) / den, 2)
        else:  # simple / authored
            out[basis] = row.get(plan[2])
    return out


def render_for(m):
    plan = sqlgen.METRIC_PLAN[m.id]
    return plan, sqlgen.SECTION_BUILDER[plan[0]]


def cmd_metric(mid, month, execute):
    m = METRICS.get(mid)
    if not m: refuse(f"'{mid}' is not a registered metric — try --list")
    if m.id not in sqlgen.METRIC_PLAN: refuse(f"'{mid}' has no SQL plan yet (registered but not built)")
    plan, builder = render_for(m)
    sql = builder(month)
    assert_read_only(sql)              # what you see is byte-for-byte what would run
    print(f"\n### {m.id} — {m.definition}\n")
    print(sql)
    if plan[1] == "authored":
        print("\n[NOTE] AUTHORED metric — its raw count column is not emitted by the current SQL slice; "
              "definition pending owner confirmation (see registry flags). No number computed.")
    print("\n" + footer(m, executed=execute, state_enum_confirmed=STATE_ENUM_CONFIRMED))
    if not execute:
        print("\n(dry-run — nothing executed. Add --execute to run, once pre-work P1 is done.)")
        return
    # ---- execute path (guarded) ----
    if not STATE_ENUM_CONFIRMED:
        refuse("--execute blocked: pre-work P1 (orders.state enum) is unconfirmed. "
               "Confirm the enum and set STATE_ENUM_CONFIRMED=True first.")
    if m.both_bases and not OFFLINE_STATUS_CONFIRMED:
        refuse("--execute blocked: this metric reports an incl_offline basis but the offline "
               "status_code->enum mapping is unconfirmed (OFFLINE_STATUS_CONFIRMED=False). "
               "Confirm the offline mapping first, or query a non-both-bases metric.")
    rows = _execute(sql)
    by_basis = {r["basis"]: r for r in rows}
    vals = compute(by_basis, plan)
    print("\nRESULT (unvalidated):")
    for basis, v in vals.items():
        print(f"  {basis}: {v}")


def _execute(sql):
    import snowflake.connector  # lazy
    conn = snowflake.connector.connect(
        account=os.environ["SF_ACCOUNT"], user=os.environ["SF_USER"], password=os.environ["SF_PASSWORD"],
        warehouse=os.environ.get("SF_WAREHOUSE", "COMPUTE_WH"),
        role=os.environ.get("SF_ROLE", ""),  # ⚠ set a READ-ONLY role — the true boundary (research rec 4)
    )
    try:
        cur = conn.cursor()
        cur.execute("ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS = 120")  # resource guard (blind-check #11)
        cur.execute(sql)
        cols = [d[0].lower() for d in cur.description]
        return [dict(zip(cols, r)) for r in cur.fetchall()]
    finally:
        conn.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--metric")
    ap.add_argument("--question")
    ap.add_argument("--month", default="2026-04")
    ap.add_argument("--execute", action="store_true")
    a = ap.parse_args()
    if a.list: return cmd_list()
    mid = a.metric
    if a.question:
        mid, why = resolve(a.question, METRICS)
        print(f"[resolve] {why}" + (f" -> {mid}" if mid else ""))
        if not mid: refuse(why)
    if not mid: refuse("nothing to do — pass --list, --metric <id>, or --question '...'")
    cmd_metric(mid, a.month, a.execute)


if __name__ == "__main__":
    main()
