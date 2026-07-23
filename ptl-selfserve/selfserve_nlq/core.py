# core.py
"""
Self-Serve NL Query Layer — SHARED CORE ENGINE (vertical-agnostic)
==================================================================
Per DECISION_LOG D7: this module holds the mechanical, non-metric machinery that PnM and PTL
(and later HCV) share. It contains ZERO metric definitions and ZERO SQL — only:
  • the metric-entry SCHEMA (MetricFlow-shaped) that every vertical's registry fills in
  • the read-only SQL guard (assert_read_only) — regex tripwire + optional sqlglot AST allow-list
  • the closed-world resolver (NL alias -> metric_id, or an explicit refusal)
  • the answer/trust footer renderer
  • section-level readiness semantics

Forward-migration (D7): PTL imports this now; PnM migrates to it later. When PnM migrates,
this file is promoted to a shared path. Until then it lives under ptl-selfserve/ to respect the
file-zone boundary.

The AI layer may ONLY select metric ids that a registry exposes — it never authors SQL. The
tool boundary enforces this: Snowflake credentials are exercised only through ask.py --execute,
which refuses any id not in the registry.
"""
from __future__ import annotations
import re
from dataclasses import dataclass, field
from typing import Optional

# ── readiness (per section, inherited by its metrics) ─────────────────────────
#   prototype_only    works for the analyst; open flags / unvalidated numbers
#   stakeholder_ready promoted BY THE OWNER ONLY after flags cleared + live validation
#   blocked           cannot be queried until a structural issue is fixed
#   not_built         not part of this iteration
READINESS = ("prototype_only", "stakeholder_ready", "blocked", "not_built")


@dataclass
class Metric:
    """One registry entry. MetricFlow-shaped so export to a governed metric store is mechanical
    (dbt Semantic Layer: type / measure / numerator+denominator / agg_time_dimension)."""
    id: str
    section: str
    level: str                       # NSM / L0 / L1 / L2
    unit: str                        # 'customers', 'orders', '%', 'orders/trip', 'INR', ...
    definition: str                  # one-line business definition
    source: str                      # snowflake | amplitude | freshdesk | datadog | finance | manual
    metric_type: str = "simple"      # simple | ratio | derived
    numerator: Optional[str] = None  # for ratio: the count-metric id used as numerator
    denominator: Optional[str] = None
    scale: float = 1.0               # e.g. 100 for a percentage
    card_id: Optional[str] = None    # source Metabase card/dashboard id, or None if authored
    tables: tuple = ()               # underlying physical tables (as traced)
    both_bases: bool = False         # D3: emit with AND without offline gsheet orders
    verify_flags: tuple = ()         # carried VERBATIM; never silently resolved
    readiness: str = "prototype_only"
    aliases: tuple = ()

    def __post_init__(self):
        assert self.readiness in READINESS, f"bad readiness {self.readiness!r}"
        assert self.source in ("snowflake", "amplitude", "freshdesk", "datadog", "finance", "manual")


# ── read-only SQL guard ───────────────────────────────────────────────────────
_WRITE_KW = re.compile(
    r"\b(CREATE|INSERT|UPDATE|DELETE|MERGE|DROP|ALTER|TRUNCATE|COPY|GRANT|REVOKE|CALL)\b", re.I)


def assert_read_only(sql: str) -> None:
    """Defense in depth. This layer must ship nothing but a single SELECT.
    Layer 1 (here): cheap regex tripwire. Layer 2 (optional): sqlglot AST allow-list —
    single statement whose root is a SELECT/WITH. Layer 3 (deploy): a read-only Snowflake role
    (the only boundary a bypassed string check can't defeat) — enforced in ask.py's connect.
    A parse failure is treated as REFUSE, never 'run it anyway'."""
    body = sql.strip()
    if not (body.upper().startswith("WITH") or body.upper().startswith("SELECT")):
        raise ValueError("only SELECT statements are allowed")
    clean = _strip_strings_and_comments(body)   # a ';' or keyword inside a comment/literal is not a statement
    if ";" in clean.rstrip().rstrip(";"):
        raise ValueError("multiple statements are not allowed")
    if _WRITE_KW.search(clean):
        raise ValueError("write/DDL keyword detected — refusing")
    if re.search(r"system\$|\bexecute\b", clean, re.I):
        raise ValueError("side-effecting function / EXECUTE detected — refusing")
    if re.search(r"\{\{|\}\}|<[a-z_]+>|\{[a-z_]+\}", body):
        raise ValueError("unsubstituted parameter left in SQL")
    _try_sqlglot(body)


def _strip_strings_and_comments(sql: str) -> str:
    """Neutralise literals + comments before the keyword/statement checks. Comments collapse to
    EMPTY (not a space) so a split keyword like DEL/**/ETE rejoins to DELETE and is still caught."""
    sql = re.sub(r"--[^\n]*", "", sql)
    sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    sql = re.sub(r"\$\$.*?\$\$", " '' ", sql, flags=re.S)   # Snowflake dollar-quoted strings
    sql = re.sub(r"'(?:''|[^'])*'", " '' ", sql)
    return sql


def _try_sqlglot(body: str) -> None:
    """Optional stronger gate. If sqlglot isn't installed we fall back to the regex above —
    we never make it a hard dependency without an owner OK (house rule)."""
    try:
        import sqlglot
        from sqlglot import expressions as exp
    except Exception:
        return
    stmts = sqlglot.parse(body, read="snowflake")
    if len([s for s in stmts if s is not None]) != 1:
        raise ValueError("AST: exactly one statement required")
    root = stmts[0]
    if not isinstance(root, (exp.Select, exp.Subquery, exp.With, exp.Union)):
        raise ValueError(f"AST: root is {type(root).__name__}, not a SELECT")


# ── closed-world resolver ─────────────────────────────────────────────────────
# Unsupported grains/dims are refused outright rather than silently answered PTL-wide-monthly.
_UNSUPPORTED = re.compile(r"\b(city|route|vendor|owner-wise|weekly|daily|median|percentile|by month over month)\b", re.I)


def resolve(question: str, metrics: dict) -> tuple[Optional[str], str]:
    """Return (metric_id, reason). metric_id is None on refusal — the reason explains why.
    Deterministic: exact-id, then alias substring, then refuse. Never guesses across ties."""
    q = question.lower().strip()
    if q in metrics:
        return q, "exact id"
    if _UNSUPPORTED.search(q):
        return None, ("refused: this layer answers PTL-wide monthly registered metrics only — "
                      "city/route/vendor/weekly/daily/percentile cuts are not in the registry")
    hits = []
    for mid, m in metrics.items():
        for a in m.aliases:
            if a.lower() in q:
                hits.append((len(a), mid))
    if not hits:
        return None, "refused: no registered metric matches — rephrase or check `--list`"
    hits.sort(reverse=True)  # longest alias wins
    top = [mid for ln, mid in hits if ln == hits[0][0]]
    if len(set(top)) > 1:
        return None, f"refused: ambiguous between {sorted(set(top))} — name the metric id"
    return hits[0][1], f"matched alias"


# ── trust footer ──────────────────────────────────────────────────────────────
def footer(m: Metric, executed: bool, state_enum_confirmed: bool) -> str:
    lines = [
        "─" * 68,
        f"metric: {m.id}  ·  section: {m.section}  ·  readiness: {m.readiness.upper()}",
        f"source: {m.source}" + (f" (card {m.card_id})" if m.card_id else " (AUTHORED — no card oracle)"),
        f"mode: {'EXECUTED against Snowflake' if executed else 'DRY-RUN — nothing was executed'}",
    ]
    if m.both_bases:
        lines.append("offline base: D3 UNSETTLED — both WITH and WITHOUT gsheet offline orders are shown")
    if not state_enum_confirmed:
        lines.append("⚠ orders.state enum (3=completed/4=cancelled) is ASSUMED, not confirmed (pre-work P1)")
    for f in m.verify_flags:
        lines.append(f"⚠ flag: {f}")
    lines.append("Not stakeholder-ready — numbers are unvalidated until the owner-run reconciliation round.")
    lines.append("─" * 68)
    return "\n".join(lines)
