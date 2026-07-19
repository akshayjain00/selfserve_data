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
        "built": True,
        "readiness": "prototype_only",
        # [board-fix] corrected from the stale stub value "o_completed_ts".
        "month_basis": "calendar month of SHIFTING_TS_IST (shifting/execution month)",
        "base_population": (
            "completed (ORDER_STATUS='completed'), intra-city (SHIFTING_TYPE='intra_city'), NON-Nano "
            "(PACKAGE_NAME NOT ILIKE 'Nano%') orders from PROD_ELDORIA.MART.PNM_EXPERIENCE, filtered to "
            "the requested SHIFTING_TS_IST month; percentiles taken over per-order stage durations (minutes)"
        ),
        "source_desc": (
            "PnM MBR catalog §p80_durations — mirrors the owner's live-validated MBR automation "
            "(TRIP_DURATION_PERCENTILE_QUERY) over PROD_ELDORIA.MART.PNM_EXPERIENCE"
        ),
        "computed_desc": (
            "live at query time from the governed mart PROD_ELDORIA.MART.PNM_EXPERIENCE "
            "(PERCENTILE_CONT over stage durations); reconcile against the p80 baseline CSV / MBR note"
        ),
        "verify_flags": [
            "PNM_EXPERIENCE is flagged in-source as 'still under active construction'; all 20 required "
            "columns + NTZ types on SHIFTING_TS_IST were verified live 2026-07-19 — re-verify before each run.",
            "p80_vendor_accepted_to_sup_assigned and p50_trip_duration are emitted + reconciled but NOT "
            "NL-exposed (ask.py --metric only); p50 is additionally blocked by the p50/median guard (D10).",
        ],
        "quirks": [
            "'Supervisor Assigned' reads SUPERVISOR_ACCEPTED_TS_IST (NOT SUPERVISOR_ASSIGNED_TS_IST, which "
            "also exists in the mart) — replicated bug-for-bug from the automation; affects the "
            "vendor→sup-assigned and sup-assigned→trip-started stages.",
            "The pickup→order-complete stage is labelled '…→ Shifting Complete' in the automation; the "
            "metric measures PICKUP_COMPLETED_TS_IST → ORDER_COMPLETED_TS_IST.",
            "Stage durations use DATEDIFF('minute', ...); an order with a NULL endpoint drops out of that "
            "stage's percentile, and an empty partition yields NULL (not 0).",
        ],
        "evidence": [
            "MIRRORS TRIP_DURATION_PERCENTILE_QUERY (owner's live-validated automation). The baseline "
            "reference/p80_durations_baseline_2025-10_to_2026-05.csv IS this automation's output; its 7 "
            "non-MONTH columns map 1:1 to the 7 metric ids. Source = PROD_ELDORIA.MART.PNM_EXPERIENCE (D8); "
            "the earlier stub's month_basis (o_completed_ts) is corrected to SHIFTING_TS_IST.",
        ],
    },
    "order_edits": {
        "built": True,
        "readiness": "prototype_only",
        # [board-fix] corrected from the stale stub value "o_created_ts"; stale
        # sr_modifications / order_modifications verify_flags + evidence REPLACED (not appended).
        "month_basis": "calendar month of ORDER_CREATED_TS_IST (order creation month)",
        "base_population": (
            "completed (ORDER_STATUS='completed'), intra-city (SHIFTING_TYPE='intra_city'), NON-Nano "
            "(PACKAGE_NAME NOT ILIKE 'Nano%') orders from PROD_ELDORIA.MART.PNM_EXPERIENCE, filtered to "
            "the requested ORDER_CREATED_TS_IST month"
        ),
        "source_desc": (
            "PnM MBR catalog §order_edits — mirrors the owner's live-validated MBR automation "
            "(EDIT_ADOPTION_QUERY) over PROD_ELDORIA.MART.PNM_EXPERIENCE"
        ),
        "computed_desc": (
            "live at query time from the governed mart PROD_ELDORIA.MART.PNM_EXPERIENCE "
            "(edit-flag adoption rates); reconcile against the MBR note"
        ),
        "verify_flags": [
            "PNM_EXPERIENCE is flagged in-source as 'still under active construction'; all required "
            "columns + NTZ types on ORDER_CREATED_TS_IST were verified live 2026-07-19 — re-verify before each run.",
        ],
        "quirks": [
            "location adoption is emitted under TWO ids with the identical expression "
            "(location_adoption_pct == pct_orders_location_modified) — duplicated bug-for-bug from the "
            "automation; distinct aliases keep the resolver from tying.",
            "pct_edits_after_shifting_started divides by NO_OF_SUCCESSFUL_EDITS (not total_orders); every "
            "other % divides by total_orders. It can exceed 100% if edits_after_shifting > successful_edits.",
            "No sample-size / denominator column is emitted (owner: exact mirror, no companion) — so a % is "
            "shown without a visible denominator, unlike tpo's orders_base.",
            "IS_MODIFICATION_DONE is compared to the string 'Yes'; the HAS_*_EDIT flags to the number 1 "
            "(column types verified live 2026-07-19).",
        ],
        "evidence": [
            "MIRRORS EDIT_ADOPTION_QUERY (owner's live-validated automation) over "
            "PROD_ELDORIA.MART.PNM_EXPERIENCE (D8) — SUPERSEDES the earlier stub that sourced this section "
            "from PROD_CURATED.pnm_application.sr_modifications / order_modifications; those flags and "
            "evidence are REMOVED (not appended) so the footer no longer discloses the wrong tables.",
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

    # ── p80_durations (p80 of per-order stage durations, minutes) ─────────────
    # Ids = the automation's exact output-column names, lowercase (D9). The vendor
    # and p50 stages carry NO NL aliases (reachable only via --metric): the earlier
    # "vendor guard excludes it" rationale was FALSE (bare 'vendor' is not in
    # UNSUPPORTED_TERMS and adding it would break tpo_vendor_raised) — so exclusion
    # is done by giving no alias, not by the guard. p50 is also guard-blocked (D10).
    "p80_vendor_accepted_to_sup_assigned": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p80 minutes from vendor-owner acceptance to supervisor assignment (reads SUPERVISOR_ACCEPTED_TS_IST). --metric only.",
        "aliases": []},
    "p80_sup_assigned_to_trip_started": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p80 minutes from supervisor assignment (SUPERVISOR_ACCEPTED_TS_IST) to trip start.",
        "aliases": ["p80 supervisor assigned to trip started", "p80 sup assigned to trip started",
                    "supervisor assigned to trip started duration"]},
    "p80_trip_started_to_shifting_started": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p80 minutes from trip start to shifting start.",
        "aliases": ["p80 trip started to shifting started", "trip started to shifting started duration"]},
    "p80_shifting_started_to_pickup_complete": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p80 minutes from shifting start to pickup completion.",
        "aliases": ["p80 shifting started to pickup complete", "p80 shifting started to pickup completed",
                    "shifting started to pickup complete duration"]},
    "p80_pickup_complete_to_order_complete": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p80 minutes from pickup completion to order completion (labelled '…→ Shifting Complete' in the automation).",
        "aliases": ["p80 pickup complete to order complete", "p80 pickup complete to shifting complete",
                    "pickup complete to order complete duration"]},
    "p50_trip_duration": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p50 (median) minutes from shifting start to order completion. Emitted + reconciled but NOT NL-exposed (D10 p50/median guard); --metric only.",
        "aliases": []},
    "p80_trip_duration": {"section": "p80_durations", "unit": "minutes", "source": "sql",
        "definition": "p80 minutes from shifting start to order completion (overall trip duration).",
        "aliases": ["p80 trip duration", "p80 total trip duration", "80th percentile trip duration", "p80 trip time"]},

    # ── order_edits (edit adoption; % unless noted) ───────────────────────────
    # Every metric is source:"sql" — the automation emits the final %s (unlike
    # leads/orders which emit counts and derive %s in Python). location adoption is
    # duplicated under two ids by design; the two get disjoint aliases so resolve()
    # never ties. Ids = automation output columns, lowercase (D9).
    "pct_orders_edited": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders with at least one modification (IS_MODIFICATION_DONE='Yes').",
        "aliases": ["percent orders edited", "orders edited", "share of orders edited", "order edit rate",
                    "overall edit adoption", "edit adoption rate"]},
    "no_of_successful_edits": {"section": "order_edits", "unit": "edits", "source": "sql",
        "definition": "Total successful edits across all orders in the month (a count, not a %).",
        "aliases": ["number of successful edits", "total successful edits", "successful edits", "total edits"]},
    "pct_support_edited_orders": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders that had a support-driven edit (HAS_SUPPORT_EDIT=1).",
        "aliases": ["percent support edited orders", "support edited orders", "support edit adoption"]},
    "location_adoption_pct": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders with a location edit (HAS_LOCATION_EDIT=1). Identical value to pct_orders_location_modified.",
        "aliases": ["location edit adoption", "location adoption", "location adoption rate"]},
    "pct_orders_location_modified": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders with a location modification — identical value to location_adoption_pct (duplicated by the automation).",
        "aliases": ["percent orders location modified", "orders location modified", "percent of orders with a location change"]},
    "items_adoption_pct": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders with an items edit (HAS_ITEMS_EDIT=1).",
        "aliases": ["items edit adoption", "items adoption", "item edit adoption"]},
    "addons_adoption_pct": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders with an add-ons edit (HAS_ADDONS_EDIT=1).",
        "aliases": ["addons edit adoption", "addons adoption", "add-ons adoption", "addon adoption"]},
    "slot_adoption_pct": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of orders with a slot/time edit (HAS_SLOT_EDIT=1).",
        "aliases": ["slot edit adoption", "slot adoption", "slot change adoption"]},
    "edits_per_order": {"section": "order_edits", "unit": "edits/order", "source": "sql",
        "definition": "Average successful edits per order (no_of_successful_edits ÷ total_orders).",
        "aliases": ["edits per order", "average edits per order", "number of edits per order"]},
    "pct_edits_after_shifting_started": {"section": "order_edits", "unit": "%", "source": "sql",
        "definition": "% of successful edits that occurred after shifting started (÷ no_of_successful_edits, not total_orders).",
        "aliases": ["percent edits after shifting started", "edits after shifting started",
                    "share of edits after shifting"]},
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
        # A metric with no aliases is intentionally NOT NL-exposed (reachable only via
        # ask.py --metric). Skip it entirely so it can't be matched even by its id-form
        # (e.g. p80_vendor_accepted_to_sup_assigned, p50_trip_duration).
        if not spec["aliases"]:
            continue
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
