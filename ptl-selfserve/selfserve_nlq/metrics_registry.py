# metrics_registry.py
"""
PTL Self-Serve NL Query Layer — Metric Registry (v0, iteration 2 / Track B)
===========================================================================
The single source of truth the NL layer resolves against. The AI selects metric ids from here;
it never authors SQL. Shaped per core.Metric (MetricFlow-like) so export to a governed metric
store is mechanical later.

Scope = the 11-metric v1 bundle locked in DECISION_LOG D6. All source=snowflake, on RAW
`prod_curated.partload_application` (D2: raw now, governed later). Nothing is stakeholder_ready;
readiness is owner-promoted only.

Flags are carried VERBATIM and are NOT resolved here. Two cross-cutting assumptions apply to
every metric below and are surfaced in every answer footer:
  • orders.state enum 3=completed / 4=cancelled is ASSUMED (pre-work P1, unconfirmed).
  • internal/test mobiles are excluded via partload_analytics.ptl_internal_users.
"""
from core import Metric

STATE_ENUM_CONFIRMED = False       # pre-work P1 — flip True only after the data-dictionary check
OFFLINE_STATUS_CONFIRMED = False   # gsheet offline status_code -> enum mapping unconfirmed (blind-check finding #1)

CONFIG_WIDE_FLAGS = (
    "orders.state enum (3=completed, 4=cancelled) assumed, not confirmed (P1)",
    "offline gsheet status_code -> enum is UNMAPPED (unrecognised -> NULL, not counted); incl_offline completed/cbdf/cadf unreliable until OFFLINE_STATUS_CONFIRMED",
    "business-user filter (customers.frequency IN (1,2,3,4)) source+key unconfirmed: oms_public.customers vs prod_eldoria.core.dim_customers (§3.5)",
    "internal-user exclusion applied inconsistently across source cards (catalog §3)",
    "Metabase db108 vs db73 not yet confirmed to be the same Snowflake account (P2)",
)

# section -> readiness (inherited by its metrics). All prototype_only in v1.
SECTIONS = {
    "demand":        {"readiness": "prototype_only"},
    "fulfilment":    {"readiness": "prototype_only"},
    "cancellations": {"readiness": "prototype_only"},
    "marketplace":   {"readiness": "prototype_only"},
    "retention":     {"readiness": "prototype_only"},
}

_RAW = ("prod_curated.partload_application.orders",)
_OFFLINE = "prod_curated.gsheet_sync.ptl_offline_orders"

METRICS = {m.id: m for m in [
    # ── demand ────────────────────────────────────────────────────────────────
    Metric(
        id="nsm_txn_business_customers", section="demand", level="NSM", unit="customers",
        definition="Distinct business customers with >=1 completed PTL order in the month (North Star, D4).",
        source="snowflake", metric_type="simple", card_id=None, both_bases=True,
        tables=_RAW + ("+ customer classification (dim_customers OR oms_public.customers)",),
        verify_flags=(
            "AUTHORED — no source card; definition written from D4, must be owner-confirmed",
            "customer Business/Personal source+key drift (catalog §3.5): dim_customers.customer_uuid vs oms_public.customers on customer_mobile",
        ),
        aliases=("nsm", "north star", "monthly transacting business customers", "transacting customers"),
    ),
    Metric(
        id="completed_orders_business", section="demand", level="L0", unit="orders",
        definition="Count of completed PTL orders by business users in the month.",
        source="snowflake", metric_type="simple", card_id="33462", both_bases=True,
        tables=_RAW + ("partload_application.order_vehicles", _OFFLINE, "prod_eldoria.core.dim_customers"),
        verify_flags=("card 33462 UNIONs offline orders; base differs from cards that exclude them (§3.3)",),
        aliases=("completed orders", "business orders", "orders", "order count"),
    ),
    Metric(
        id="new_business_users", section="demand", level="L1", unit="users",
        definition="Count of new business users (first completed PTL order) in the month.",
        source="snowflake", metric_type="simple", card_id="48921", both_bases=True,
        tables=_RAW + ("prod_curated.oms_public.customers",),
        verify_flags=("card 48921 counts ONLINE only; classification from oms_public.customers (frequency IN (1,2,3,4))",),
        aliases=("new business users", "new users", "acquired users", "first order users"),
    ),
    Metric(
        id="business_session_conversion", section="demand", level="L0", unit="%",
        definition="Share of PTL business-user sessions that result in a placed order.",
        source="snowflake", metric_type="ratio", numerator="orders", denominator="sessions", scale=100.0,
        card_id="48491", both_bases=False,   # D6 note: offline orders have no session -> not applicable
        tables=("partload_analytics.ptl_fe_events",) + _RAW + ("prod_eldoria.core.dim_customers",),
        verify_flags=("session funnel — offline base does NOT apply (no session for offline orders)",),
        aliases=("session conversion", "business session conversion", "conversion rate"),
    ),
    # ── fulfilment ──────────────────────────────────────────────────────────────
    Metric(
        id="total_fulfilment_pct", section="fulfilment", level="L0", unit="%",
        definition="Completed / placed PTL orders (also tracked excluding <60s cancellations).",
        source="snowflake", metric_type="ratio", numerator="completed", denominator="placed", scale=100.0,
        card_id="4198", both_bases=True,
        tables=_RAW + ("partload_application.order_cancellation_reasons", _OFFLINE),
        verify_flags=("dashboard 4198 has a separate '<60s excluded' variant (43238) — report both",),
        aliases=("fulfilment", "ff", "total fulfilment", "fulfillment", "ff%"),
    ),
    Metric(
        id="effective_fulfilment_pct", section="fulfilment", level="L1", unit="%",
        definition="Completed / (placed - customer-attributed cancellations).",
        source="snowflake", metric_type="ratio", numerator="completed", denominator="placed_less_cx_cancels", scale=100.0,
        card_id="48581", both_bases=True,
        tables=_RAW + ("partload_application.order_cancellation_reasons", "partload_analytics.ptl_internal_users"),
        verify_flags=(
            "card 48581 EXCLUDES offline — base differs from total_fulfilment_pct's 4198 (§3.3)",
            "prototype denominator = placed − cbdf_cancels (APPROXIMATION); card 48581's exact 'customer-attributed cancellations' needs confirming",
        ),
        aliases=("effective fulfilment", "effective ff", "eff ff"),
    ),
    # ── cancellations (D5: dashboard 4793 canonical; confirm 49366 reconciles) ───
    Metric(
        id="cbdf_pct", section="cancellations", level="L1", unit="%",
        definition="Cancellations BEFORE a driver/vehicle is found / placed orders (D5: dashboard 4793 logic).",
        source="snowflake", metric_type="ratio", numerator="cbdf_cancels", denominator="placed", scale=100.0,
        card_id="4793", both_bases=True,
        tables=_RAW + ("partload_application.order_cancellation_reasons", "partload_application.order_vehicles"),
        verify_flags=(
            "TWO parallel defs (§3.4): dashboard 4793 (canonical, D5) vs card 49366 (vehicle_name IS NULL). Confirm reconcile.",
            "prototype uses 49366-style vehicle-assigned signal and does NOT yet apply 4793's <60s exclusion → cancel counts over-stated until reconciled",
        ),
        aliases=("cbdf", "cancellation before driver found", "cbdf%"),
    ),
    Metric(
        id="cadf_pct", section="cancellations", level="L1", unit="%",
        definition="Cancellations AFTER a driver/vehicle is found / placed orders (D5: dashboard 4793 logic).",
        source="snowflake", metric_type="ratio", numerator="cadf_cancels", denominator="placed", scale=100.0,
        card_id="4793", both_bases=True,
        tables=_RAW + ("partload_application.order_cancellation_reasons", "partload_application.order_vehicles"),
        verify_flags=("TWO parallel defs (§3.4): 4793 canonical vs 49366. Confirm reconcile.",),
        aliases=("cadf", "cancellation after driver found", "cadf%"),
    ),
    # ── marketplace ─────────────────────────────────────────────────────────────
    Metric(
        id="avg_orders_per_trip", section="marketplace", level="L0", unit="orders/trip",
        definition="Fulfilled orders / trips where >=2 orders shared a route+date (clubbing).",
        source="snowflake", metric_type="ratio", numerator="clubbed_orders", denominator="clubbing_trips", scale=1.0,
        card_id="33461", both_bases=True,
        tables=("partload_application.batched_orders_v1", "partload_application.order_vehicles") + _RAW + (_OFFLINE,),
        verify_flags=("card 33461 UNIONs offline orders (§3.3)",),
        aliases=("avg orders per trip", "orders per trip", "clubbing", "clubbing ratio"),
    ),
    Metric(
        id="aov", section="marketplace", level="L1", unit="INR",
        definition="Total revenue from completed orders / count of completed orders.",
        source="snowflake", metric_type="ratio", numerator="revenue", denominator="completed", scale=1.0,
        card_id="33706", both_bases=True,
        tables=_RAW + ("partload_analytics.ptl_routes",),
        verify_flags=(
            "card 33706 buckets by updated_at, not created_at like the funnel (§3.6) — pick one date basis",
            "card 33706 EXCLUDES offline (§3.3)",
        ),
        aliases=("aov", "average order value", "order value"),
    ),
    # ── retention ─────────────────────────────────────────────────────────────
    Metric(
        id="m1_business_retention_pct", section="retention", level="L0", unit="%",
        definition="Share of month-0 business users who place >=1 PTL order in month+1.",
        source="snowflake", metric_type="ratio", numerator="m0_retained", denominator="m0_business_users", scale=100.0,
        card_id="4569", both_bases=True,
        tables=_RAW + ("prod_curated.oms_public.customers",),
        verify_flags=("cohort/retention — confirm month-0 base and completed-vs-placed basis on dashboard 4569",),
        aliases=("m1 retention", "business retention", "m1 business user retention"),
    ),
]}

# metrics deferred from v1 (recorded so the menu is honest about what it does NOT cover)
DEFERRED = {
    "time_to_allocate_p50": "manual sheet source, no verified card — iteration 2.5 (D6)",
}
