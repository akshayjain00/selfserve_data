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

# ─────────────────────────────────────────────────────────────────────────────
# CROSS-CUTTING BLOCKER discovered post-iteration-2 review (2026-07-07), affects
# EVERY order-based section (orders, derived, tpo — and later p80, order_edits).
# NOT a resolution — a decision teed up for the owner, stated with confidence.
# ─────────────────────────────────────────────────────────────────────────────
ORDERS_SOURCE_DECISION = {
    "finding": (
        "The staging query reads order_id, o_created_ts, o_completed_ts, customer_id, "
        "status(=2/!=4 numeric), and the lifecycle timestamps (vendor_accepted_ts, "
        "supervisor_assigned_ts, trip_started_ts, shifting_started_ts, pickup_completed_ts, "
        "order_completed_ts) from PROD_CURATED.pnm_application.orders. Data Catalog shows that "
        "raw table has only: id, crn, sr_id, source, created_at, updated_at, status(TEXT), "
        "service_type, mobile. NONE of the columns the query needs exist there."
    ),
    "evidence": (
        "The compiled SQL of PROD_ELDORIA.core.fact_pnm_orders (NI_PNM-owned dbt model) "
        "ASSEMBLES those columns from multiple raw tables: o.id->order_id, o.created_at_ist-> "
        "o_created_ts, allocation_infos.completed_ts_ist->o_completed_ts, supervisor_actions-> "
        "trip/shifting/pickup/order_completed OLC timestamps, allocation_infos-> "
        "supervisor_assigned/accepted & vendor_owner_accepted. It exposes order_id, o_created_ts, "
        "o_completed_ts, crn, customer_mobile, sr_id and all lifecycle timestamps (some renamed, "
        "e.g. trip_started_olc_ts, vendor_owner_accepted_ts; NO 'status' column)."
    ),
    "confidence": (
        "~95% the configured raw table lacks the needed columns (so leads/orders/derived/tpo "
        "cannot execute as written); ~90% core.fact_pnm_orders (+ dim_pnm_orders, mart.pnm_customers, "
        "core.fact_pnm_opportunity) is the intended source. This aligns with Metabase card #30311, "
        "which reads exactly these prod_eldoria core/mart models."
    ),
    "implication": (
        "'Bug-for-bug fidelity to the pipeline' is fidelity to a pipeline that almost certainly "
        "never ran (named-colon binds + missing columns + 'verify before first run'). There is no "
        "sheet baseline to match, which weakens the case for staying on raw tables. Re-pointing "
        "sections to the eldoria core/mart dbt models is now the stronger path AND it directly "
        "unblocks Argus eligibility (governed models + semantic models already exist)."
    ),
    "choice_for_owner": (
        "(A) Re-point all sections to PROD_ELDORIA core/mart dbt models — RECOMMENDED (~85% this is "
        "right), a definition change but it makes the numbers real and Argus-ready; column names and "
        "status->completed/cancelled semantics must be re-mapped and re-validated. "
        "(B) Keep bug-for-bug on raw pnm_application tables — will not execute; only useful as a "
        "record of the original (broken) intent. (~15%)"
    ),
    "status": "RESOLVED 2026-07-08 — owner chose (A); sqlgen.py now MIRRORS the owner's live-validated MBR automation.",
    "resolution": (
        "Owner approved (A) on 2026-07-08. Rather than hand-re-map the old raw-table staging, sqlgen.py now MIRRORS "
        "the owner's live-validated automation at pnm/pnm_mbr_monthly_metrics/queries.py: leads/orders/derived follow "
        "LEADS_CONVERSION_QUERY (validated 2026-07-08 vs PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY / DIM_PNM_OPPORTUNITY / "
        "FACT_PNM_ORDERS / DIM_PNM_ORDERS and PROD_ELDORIA.MART.PNM_CUSTOMERS); tpo follows TPO_TREND_QUERY / card #47576 "
        "(validated 2026-07-07 vs PROD_CURATED.PNM_APPLICATION.ORDERS / ORDER_ALLOCATION_INFOS / SHIFTING_REQUIREMENTS and "
        "PROD_CURATED.SFMS_PUBLIC.HS_TICKETS). Key semantics adopted from the validated queries: intra-city via "
        "shifting_type='intra_city' (on the dims, nulls allowed on leads); user_flag ILIKE 'normal'; channel via a CASE on "
        "dim_pnm_opportunity.source/source_details (App=1/2/3, Desktop/Mobile Website, Others=4, ELSE Mobile Website); "
        "orders joined to mart.pnm_customers on customer_mobile with crn LIKE '%PNM%'; order dedup per ORDER_ID on the "
        "opp-join fan-out; NO cancelled filter (all created orders count); TPO denominator = distinct PnM crns with an "
        "active completed allocation (completed_ts +330m -> IST month), tickets bucketed by order_status_when_ticket_created. "
        "NANO BUSINESS RULE (owner, 2026-07-08): nano = labour-only help (no vehicle), owned by LA (Labour Assist). It is "
        "INCLUDED in leads (PnM demand) but EXCLUDED from orders (package_name NOT ILIKE 'Nano%') and TPO — those bookings "
        "are LA's. So numbers reconcile against the MBR note / Notion Demand DB, NOT card #30311 (which strips nano from "
        "the whole funnel). ADAPTATIONS (structure-only): single requested month instead of the automation's open-ended "
        "start_date; this layer emits raw per-channel COUNTS and computes %s/conversion in Python (the automation emits %s)."
    ),
}

SECTIONS = {
    "leads": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of opp_created_ts (lead creation month)",
        "base_population": (
            "intra-city (dim_pnm_opportunity.shifting_type='intra_city', nulls allowed), normal-user "
            "(user_flag ILIKE 'normal') opportunities from PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY + "
            "DIM_PNM_OPPORTUNITY; Nano INCLUDED (nano demand stays with PnM through the funnel)"
        ),
        "verify_flags": [],
        "quirks": [
            "Channel = CASE on dim_pnm_opportunity source/source_details: App=1/2/3, "
            "'Desktop Website', 'Mobile Website', Others=4, ELSE 'Mobile Website' (verbatim from "
            "the validated LEADS_CONVERSION_QUERY). Unknown/null source falls into Mobile Website.",
        ],
        "evidence": [
            "MIRRORS LEADS_CONVERSION_QUERY (owner's live-validated automation, verified 2026-07-08). "
            "source & source_details come from DIM_PNM_OPPORTUNITY, which carries SOURCE, SOURCE_DETAILS "
            "and USER_FLAG (confirmed via Data Catalog get_column_metadata).",
            "Divergence from card #30311 is INTENTIONAL: #30311 excludes Nano from the funnel; PnM "
            "keeps nano as demand in leads. Reconcile against the MBR note / Notion Demand DB.",
        ],
    },
    "orders": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of o_created_ts (order creation month)",
        "base_population": (
            "intra-city (dim_pnm_orders.shifting_type='intra_city'), normal-user orders from "
            "PROD_ELDORIA.CORE.FACT_PNM_ORDERS + DIM_PNM_ORDERS with a matching PROD_ELDORIA.MART.PNM_CUSTOMERS "
            "row (customer_mobile) and crn LIKE '%PNM%'; NON-Nano (package_name NOT ILIKE 'Nano%'); "
            "all statuses (no cancelled filter); deduped to one row per order_id"
        ),
        "verify_flags": [],
        "quirks": [
            "Channel is inherited from the order's originating lead (opportunity dim via sr_id); an order "
            "with no matching opportunity falls into the CASE ELSE bucket ('Mobile Website').",
            "Dedup is per ORDER_ID (the opp join can fan out); ORDER BY opp_id DESC NULLS LAST picks a "
            "deterministic surviving row — matches the validated LEADS_CONVERSION_QUERY.",
            "NANO ASYMMETRY: leads INCLUDE nano but orders EXCLUDE it (nano bookings are LA's). So "
            "conversion = non-nano PnM orders / nano-inclusive PnM leads — by design.",
        ],
        "evidence": [
            "MIRRORS LEADS_CONVERSION_QUERY's order_with_source (owner's live-validated automation, "
            "2026-07-08): FACT_PNM_ORDERS INNER JOIN MART.PNM_CUSTOMERS (customer_mobile) LEFT JOIN "
            "DIM_PNM_ORDERS + FACT/DIM_PNM_OPPORTUNITY (via sr_id). No cancelled filter, no first-order-"
            "per-SR dedup (per-order_id instead), nano excluded — all straight from the validated query.",
        ],
    },
    "derived": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month; ratio of same-month leads and orders aggregates",
        "base_population": (
            "inherits the leads population (nano-INCLUDED) and the orders population (nano-EXCLUDED); "
            "conversion is non-nano PnM orders over nano-inclusive PnM leads"
        ),
        "verify_flags": [],
        "quirks": [
            "Period conversion, not lead-cohort conversion: orders created in month M ÷ leads "
            "created in month M.",
            "Ratios are computed in Python from the raw counts in one query — never by "
            "averaging stored ratios.",
            "Nano asymmetry (leads include nano, orders exclude it) slightly lowers conversion vs a "
            "symmetric definition — intentional, matches the validated LEADS_CONVERSION_QUERY.",
        ],
        "evidence": [
            "Inherits the mirrored leads + orders populations (owner decision A, 2026-07-08). "
            "ConversionPercentage = orders/opportunities, same month, computed from raw counts. "
            "Reconcile against the MBR note / Notion Demand DB, not card #30311.",
        ],
    },
    "tpo": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": (
            "calendar month of ALLOCATION COMPLETION (order_allocation_infos.completed_ts + 330m -> IST) "
            "— not order creation month"
        ),
        "base_population": (
            "distinct PnM crns (crn LIKE '%PNM%') with an ACTIVE completed allocation in the month, "
            "NON-Nano (shifting_requirements.package_name NOT ILIKE '%Nano%'), intra-city "
            "(shifting_type='intra_city'); tickets counted only if created in that same IST month, "
            "non-detractor (raised_by != 'Detractor'), non-nano (hs_package). Nano EXCLUDED (attributed to LA)."
        ),
        "verify_flags": [],
        "quirks": [
            "Tickets raised in any month other than the allocation-completion month (earlier "
            "or later) are excluded entirely, attributed to no month.",
            "Denominator counts DISTINCT crn; a crn with multiple active completed allocations is "
            "still counted once. Ticket numerators are DISTINCT ticket_number.",
            "tpo_cancelled counts tickets whose order status AT TICKET CREATION was 'cancelled' — "
            "the ticket-stage bucket is independent of the order base's status (no cancelled filter there).",
        ],
        "evidence": [
            "MIRRORS TPO_TREND_QUERY (card #47576), owner's live-validated automation (verified 2026-07-07 "
            "vs PROD_CURATED). Order base: ORDERS a JOIN ORDER_ALLOCATION_INFOS b (b.is_active=true) LEFT JOIN "
            "SHIFTING_REQUIREMENTS c; month via DATEADD(minute,330,b.completed_ts). Tickets: SFMS_PUBLIC.HS_TICKETS "
            "joined on crn, bucketed by order_status_when_ticket_created, vendor via raised_by ILIKE 'Vendor%'.",
            "This supersedes the earlier eldoria fact_pnm_orders.o_completed_ts approximation and the guessed "
            "pnm_application.tickets — both replaced by the validated PROD_CURATED sourcing.",
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
                       "definition": "Distinct non-Nano PnM booked orders created in the month (deduped per order_id; all statuses).",
                       "aliases": ["orders", "total orders", "booked orders", "how many orders", "bookings"]},
    "orders_app":     {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders whose originating lead was app (source IN (1,2,3)).",
                       "aliases": ["app orders", "orders from app", "orders from the app"]},
    "orders_desktop": {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders whose originating lead was the desktop website.",
                       "aliases": ["desktop orders", "desktop website orders"]},
    "orders_mobile":  {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders whose originating lead was the mobile website.",
                       "aliases": ["mobile orders", "mobile website orders", "mweb orders"]},
    "orders_others":  {"section": "orders", "unit": "orders", "source": "sql",
                       "definition": "Booked orders whose originating lead was another channel (source = 4).",
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
                    "definition": "Distinct non-Nano intra-city PnM crns whose allocation completed in the month (TPO denominator).",
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
