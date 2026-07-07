"""
PnM Self-Serve NL Query Layer — Metric Registry (v0, iteration 2)
=================================================================
Declarative catalog: the single source of truth the NL layer resolves against.
The AI layer may ONLY select metric ids from this registry — it never authors SQL.

Sections built in v0: leads, orders, derived, tpo.
Sections NOT built:   ota (blocked — see notes), p80_durations, order_edits (iteration 3).

Readiness semantics (per section, inherited by every metric in it):
    prototype_only     works for the analyst; open flags or unvalidated answers
    stakeholder_ready  promoted BY THE OWNER ONLY after flags cleared + live validation
    blocked            cannot be queried at all until a structural issue is fixed
    not_built          not part of this iteration

NOTHING in this file may be promoted to stakeholder_ready except by the owner
(Akshay) editing this file deliberately.

All verify flags are carried VERBATIM from config.py / queries.py and are not
resolved here. `evidence` entries record externally observed facts (Metabase
card #30311 content, Data Catalog metadata) that bear on a flag — they are
inputs to the owner's decision, not resolutions.
"""

CONFIG_WIDE_FLAGS = [
    'config.py TABLES header: "# Verify these against Snowflake before running for the first time."',
    'config.py TABLES header: "# Canonical methodology: Metabase card #30311."',
]

SECTIONS = {
    "leads": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of opp_created_ts (lead creation month)",
        "base_population": (
            "intra-city, normal-user opportunities; Nano INCLUDED "
            "(no is_nano filter in the pipeline's staging leads table)"
        ),
        "verify_flags": [
            'config.py fact_opp: "PROD_CURATED.pnm_application.fact_pnm_opprotunity"  # note: typo in source table',
        ],
        "quirks": [
            "Population limited to leads created in the requested month + previous month "
            "(pipeline staging-window semantics, replicated bug-for-bug).",
        ],
        "evidence": [
            "Metabase card #30311 ('[DBT] Conversion %') counts opportunities from "
            "prod_eldoria.core.fact_pnm_opportunity (correct spelling, different database/schema) "
            "and EXCLUDES Nano via package_name NOT ILIKE '%nano%' — the script includes Nano. "
            "Divergence unresolved; owner decision needed.",
            "Data Catalog: PROD_ELDORIA.core.fact_pnm_opportunity and dim_pnm_opportunity exist "
            "as dbt models owned by NI_PNM, with semantic models already generated — a governed "
            "alternative source exists; re-pointing is a definition change (owner decision).",
        ],
    },
    "orders": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of o_created_ts (order creation month)",
        "base_population": (
            "intra-city, normal-user orders with a matching pnm_customers row, status != 4 "
            "(status codes undocumented — inferred), first order per sr_id; Nano INCLUDED"
        ),
        "verify_flags": [],
        "quirks": [
            "Channel attribution works only when the originating lead was created in the "
            "requested month + previous month; older-lead orders count in orders_overall "
            "but in no channel split.",
            "If one sr_id has multiple in-window leads, the surviving row's source channel "
            "is nondeterministic (dedup runs after the lead join).",
        ],
        "evidence": [
            "Metabase card #30311 counts orders from prod_eldoria.core.fact_pnm_orders with "
            "NO status filter, NO first-order-per-SR dedup, Nano EXCLUDED, intra-city via "
            "service_type IN ('Default','Default_Short'), customers joined on customer_mobile. "
            "All of these differ from the script. Divergence unresolved; owner decision needed.",
        ],
    },
    "derived": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month; ratio of same-month leads and orders aggregates",
        "base_population": "inherits leads + orders populations (both Nano-inclusive)",
        "verify_flags": [],
        "quirks": [
            "Period conversion, not lead-cohort conversion: orders created in month M ÷ leads "
            "created in month M.",
            "Ratios are computed from raw counts fetched in the same query — never by "
            "averaging stored ratios.",
            "Per-channel conversion pairs a window-limited numerator (attributed orders only) "
            "with a full channel-lead denominator.",
        ],
        "evidence": [
            "Metabase card #30311 computes ConversionPercentage as orders/opportunities with "
            "Nano excluded from BOTH sides — the script includes Nano in both. Same-month "
            "period ratio in both. Divergence unresolved; owner decision needed.",
        ],
    },
    "tpo": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": (
            "calendar month of ALLOCATION COMPLETION (order_allocation_infos.completed_ts) — "
            "not order creation or completion month"
        ),
        "base_population": (
            "distinct non-Nano intra-city orders (created in the requested month + previous "
            "month — staging window) with a completed allocation in the month; tickets counted "
            "only if created in that same calendar month; raised_by LIKE '%detractor%' excluded"
        ),
        "verify_flags": [
            'queries.py §7: "⚠ VERIFY: tickets table name, raised_by / order_status_at_creation column names."',
            'config.py tickets: "PROD_CURATED.pnm_application.tickets"  # verify table name',
        ],
        "quirks": [
            "Tickets raised in any month other than the allocation-completion month (earlier "
            "or later) are excluded entirely, attributed to no month.",
            "If an order can have multiple completed allocation rows, ticket numerators "
            "inflate quadratically while COUNT(DISTINCT) protects only the denominator — "
            "unverified either way.",
            "tpo_cancelled counts tickets whose order status AT TICKET CREATION was "
            "'cancelled', over a base that excludes status-4 orders; if 4 = cancelled, this "
            "metric is structurally near-zero.",
        ],
        "evidence": [
            "Data Catalog: NO pnm_application.tickets table found. The PnM tickets table "
            "appears to be prod_curated.sfms_public.hs_tickets ('HubSpot-originated support "
            "tickets for PNM/House Shifting'): its raised_by values (Customer ~61%, "
            "Vendor-Owner ~21%, Vendor-Supervisor ~11%, Porter Support, Detractor, Chat) match "
            "this query's filters exactly; the status-at-creation column is named "
            "order_status_when_ticket_created (not order_status_at_creation); and there is NO "
            "order_id column — tickets link to orders via crn / hs_order_id. As written, this "
            "section's SQL will fail at execution. Adapting it is a definition decision for "
            "the owner, not something this layer does silently.",
            "Data Catalog: pnm_application.order_allocation_infos exists as guessed — the "
            "allocation side of TPO is confirmed.",
        ],
    },
    "ota": {
        "built": False,
        "readiness": "blocked",
        "month_basis": "calendar month of o_completed_ts",
        "base_population": "completed (status=2) non-Nano intra-city orders",
        "verify_flags": [
            'queries.py §5: "⚠ VERIFY: scheduled_pickup_ts, vendor_arrived_ts, coordinate column names."',
        ],
        "quirks": [],
        "blocked_reason": (
            "QUERY_OTA reads six columns (scheduled_pickup_ts, vendor_arrived_ts, "
            "scheduled_pickup_lon/lat, actual_arrival_lon/lat) that the pipeline's staging "
            "table never materializes — the section cannot run anywhere until its column "
            "sourcing is settled. Not buildable bug-for-bug."
        ),
        "evidence": [
            "Data Catalog: no column named scheduled_pickup_ts or vendor_arrived_ts exists in "
            "any catalogued table (133 and 79 near-matches checked, none in PnM tables). The "
            "OTA definition needs a genuine data-source decision — candidate raw material "
            "exists (e.g. pnm_application.supervisor_actions GPS event log), but choosing it "
            "is a definition decision for the owner.",
        ],
    },
    "p80_durations": {
        "built": False,
        "readiness": "not_built",
        "month_basis": "calendar month of o_completed_ts",
        "base_population": "completed non-Nano intra-city orders",
        "verify_flags": [],
        "quirks": [],
        "evidence": [],
    },
    "order_edits": {
        "built": False,
        "readiness": "not_built",
        "month_basis": "calendar month of o_created_ts",
        "base_population": "completed non-Nano intra-city orders",
        "verify_flags": [
            'queries.py §8: "⚠ VERIFY: order_modifications table name; category / source / order_phase columns."',
            'config.py order_mods: "PROD_CURATED.pnm_application.order_modifications"  # verify table name',
        ],
        "quirks": [],
        "evidence": [
            "Data Catalog shows pnm_application.sr_modifications ('modifications made to "
            "shifting requirements... items, shifting time, add-on services, locations'), "
            "which matches the four flagged categories but is keyed on SR, not order. "
            "Whether order_modifications exists is unconfirmed. Owner decision needed.",
        ],
    },
}

# metric id -> spec
#   source: "sql"      -> column produced directly by the section SQL
#           "derived"  -> computed in Python as scale * numerator / denominator
METRICS = {
    # ── leads ────────────────────────────────────────────────────────────────
    "leads_overall":  {"section": "leads", "unit": "leads", "source": "sql",
                       "definition": "Distinct PnM opportunities (booking-funnel leads) created in the month.",
                       "aliases": ["leads", "total leads", "overall leads", "opportunities", "how many leads"]},
    "leads_app":      {"section": "leads", "unit": "leads", "source": "sql",
                       "definition": "Leads originating from the Porter app (source IN (1,2,3)).",
                       "aliases": ["app leads", "leads from app", "leads from the app"]},
    "leads_desktop":  {"section": "leads", "unit": "leads", "source": "sql",
                       "definition": "Leads from the desktop website (source_details = 'Desktop Website').",
                       "aliases": ["desktop leads", "desktop website leads", "leads from desktop"]},
    "leads_mobile":   {"section": "leads", "unit": "leads", "source": "sql",
                       "definition": "Leads from the mobile website (source_details = 'Mobile Website').",
                       "aliases": ["mobile leads", "mobile website leads", "mweb leads", "leads from mobile web"]},
    "leads_others":   {"section": "leads", "unit": "leads", "source": "sql",
                       "definition": "Leads from other channels (source = 4).",
                       "aliases": ["other leads", "others leads", "leads from other channels"]},

    # ── orders ───────────────────────────────────────────────────────────────
    "orders_overall": {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Distinct booked orders created in the month (first order per service request; excludes status-4 orders).",
                       "aliases": ["orders", "total orders", "booked orders", "how many orders", "bookings"]},
    "orders_app":     {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders attributed to an app-originated lead (source IN (1,2,3)); lead must be in the query window.",
                       "aliases": ["app orders", "orders from app", "orders from the app"]},
    "orders_desktop": {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders attributed to a desktop-website lead (window caveat applies).",
                       "aliases": ["desktop orders", "desktop website orders"]},
    "orders_mobile":  {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders attributed to a mobile-website lead (window caveat applies).",
                       "aliases": ["mobile orders", "mobile website orders", "mweb orders"]},
    "orders_others":  {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders attributed to an other-channel lead (source = 4) (window caveat applies).",
                       "aliases": ["other orders", "orders from other channels"]},

    # ── derived (computed from the funnel query's raw counts) ────────────────
    "conversion_overall": {"section": "derived", "unit": "%", "source": "derived",
                           "numerator": "orders_overall", "denominator": "leads_overall", "scale": 100,
                           "definition": "Orders created in the month as a % of leads created in the same month (period conversion).",
                           "aliases": ["conversion", "conversion rate", "lead to order conversion", "overall conversion"]},
    "conversion_app": {"section": "derived", "unit": "%", "source": "derived",
                       "numerator": "orders_app", "denominator": "leads_app", "scale": 100,
                       "definition": "App-channel orders ÷ app-channel leads, same month, %.",
                       "aliases": ["app conversion", "app conversion rate"]},
    "conversion_desktop": {"section": "derived", "unit": "%", "source": "derived",
                           "numerator": "orders_desktop", "denominator": "leads_desktop", "scale": 100,
                           "definition": "Desktop-web orders ÷ desktop-web leads, same month, %.",
                           "aliases": ["desktop conversion", "desktop conversion rate"]},
    "conversion_mobile": {"section": "derived", "unit": "%", "source": "derived",
                          "numerator": "orders_mobile", "denominator": "leads_mobile", "scale": 100,
                          "definition": "Mobile-web orders ÷ mobile-web leads, same month, %.",
                          "aliases": ["mobile conversion", "mobile conversion rate", "mweb conversion"]},
    "pct_orders_app": {"section": "derived", "unit": "%", "source": "derived",
                       "numerator": "orders_app", "denominator": "orders_overall", "scale": 100,
                       "definition": "% of booked orders that came via the app.",
                       "aliases": ["order mix app", "app order share", "% orders app", "share of app orders"]},
    "pct_orders_website": {"section": "derived", "unit": "%", "source": "derived",
                           "numerator": ("orders_desktop", "orders_mobile"), "denominator": "orders_overall", "scale": 100,
                           "definition": "% of booked orders that came via website (desktop + mobile web combined).",
                           "aliases": ["order mix website", "website order share", "% orders website"]},
    "pct_orders_others": {"section": "derived", "unit": "%", "source": "derived",
                          "numerator": "orders_others", "denominator": "orders_overall", "scale": 100,
                          "definition": "% of booked orders from other channels.",
                          "aliases": ["order mix others", "others order share", "% orders others"]},

    # ── tpo ──────────────────────────────────────────────────────────────────
    "orders_base": {"section": "tpo", "unit": "orders", "source": "sql",
                    "definition": "Distinct non-Nano intra-city orders (created in the query window) whose allocation completed in the month (TPO denominator).",
                    "aliases": ["tpo base", "tpo order base", "tpo denominator", "orders in tpo base",
                                "orders in the tpo base", "how many orders in the tpo base"]},
    "tpo_overall": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                    "definition": "Support tickets per order — all non-detractor tickets ÷ orders_base.",
                    "aliases": ["tpo", "tickets per order", "overall tpo", "complaints per order", "complaints per move"]},
    "tpo_vendor_raised": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                          "definition": "Tickets raised by vendors ('Vendor-Owner','Vendor-Supervisor') per order.",
                          "aliases": ["vendor tpo", "vendor raised tpo", "vendor tickets per order"]},
    "tpo_pre_trip": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                     "definition": "Tickets raised while the order was pre-trip (open/supervisor_assigned/supervisor_accepted/vendor_accepted) per order.",
                     "aliases": ["pre trip tpo", "pre-trip tpo", "tpo before trip"]},
    "tpo_pre_trip_customer": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                              "definition": "Customer-raised subset of pre-trip tickets, per order.",
                              "aliases": ["customer pre trip tpo", "pre trip customer tpo"]},
    "tpo_trip_shift": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                       "definition": "Tickets raised during trip/shifting (trip_started/shifting_started) per order.",
                       "aliases": ["trip shift tpo", "tpo during trip", "tpo during shifting"]},
    "tpo_trip_shift_customer": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                                "definition": "Customer-raised subset of trip/shifting tickets, per order.",
                                "aliases": ["customer trip shift tpo"]},
    "tpo_pickup": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                   "definition": "Tickets raised at the pickup_completed stage, per order.",
                   "aliases": ["pickup tpo", "tpo at pickup"]},
    "tpo_pickup_customer": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                            "definition": "Customer-raised subset of pickup-stage tickets, per order.",
                            "aliases": ["customer pickup tpo"]},
    "tpo_completed": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                      "definition": "Tickets raised after order completion, per order.",
                      "aliases": ["completed tpo", "post completion tpo", "tpo after completion"]},
    "tpo_completed_customer": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                               "definition": "Customer-raised subset of post-completion tickets, per order.",
                               "aliases": ["customer completed tpo"]},
    "tpo_cancelled": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                      "definition": "Tickets whose order status AT TICKET CREATION was 'cancelled', per order (see section quirks).",
                      "aliases": ["cancelled tpo", "tpo cancelled orders", "tpo for cancelled orders"]},
    "tpo_cancelled_customer": {"section": "tpo", "unit": "tickets/order", "source": "sql",
                               "definition": "Customer-raised subset of cancelled-status tickets, per order.",
                               "aliases": ["customer cancelled tpo"]},
}


# Dimensions/grains the catalog does NOT support. If a question mentions one,
# refuse outright — substring alias matching must never silently answer a
# narrower question with a PnM-wide monthly number.
UNSUPPORTED_TERMS = [
    # geography (catalog is PnM-wide; city list from Metabase card #30311 pickers)
    "city", "cities", "citywise", "city-wise", "region", "zone", "cluster", "tier",
    "bangalore", "mumbai", "delhi", "hyderabad", "pune", "chennai", "kolkata",
    "surat", "lucknow", "coimbatore", "indore", "nagpur", "jaipur", "ahmedabad", "ahemdabad",
    # grains (catalog is monthly only)
    "weekly", "daily", "per week", "per day", "by week", "by day", "quarterly", "quarter",
    # statistics not in the catalog for these sections
    "median", "p50", "p90", "p99", "average of",
    # entities the catalog can't cut by
    "vendor wise", "vendorwise", "by vendor", "per vendor",
]


def resolve(question: str):
    """Deterministic, transparent resolver used by tests and as a convenience
    for exact phrasings. Richer natural-language mapping is the Claude session's
    job (reading --list); this function only does normalized alias/id matching
    and REFUSES on no match, ambiguity, or unsupported dimensions — it never guesses.

    Returns (metric_id, None) on success, (None, reason) on refusal.
    """
    q = " ".join(question.lower().replace("?", " ").replace(",", " ").split())
    for term in UNSUPPORTED_TERMS:
        if term in q:
            return None, (f"question mentions {term!r} — the catalog is monthly, "
                          "PnM-wide only (no city/vendor cuts, no weekly/daily grain, "
                          "no medians/percentiles for these sections)")
    hits = []
    for mid, spec in METRICS.items():
        keys = [mid.replace("_", " ")] + spec["aliases"]
        best = max((len(k) for k in keys if k in q), default=0)
        if best:
            hits.append((best, mid))
    if not hits:
        return None, "no catalog metric matches this question"
    hits.sort(reverse=True)
    top_len = hits[0][0]
    top = [mid for ln, mid in hits if ln == top_len]
    if len(top) > 1:
        return None, f"ambiguous between {sorted(top)} — ask with a specific metric id"
    return top[0], None
