"""
PnM Self-Serve NL Query Layer — Metric Registry (v0, iteration 2)
=================================================================
Declarative catalog: the single source of truth the NL layer resolves against.
The AI layer may ONLY select metric ids from this registry — it never authors SQL.

Sections built: leads, orders, derived, tpo (v0); p80_durations, order_edits (iteration 3);
ota (2026-09-04, owner-ruled 30 min + 2 km — see SECTIONS["ota"]["evidence"]).

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
        "built": True,
        "readiness": "prototype_only",
        # [board-fix 2026-09-04] REPLACED, not appended — the old blocked_reason's six-column
        # premise (scheduled_pickup_ts, vendor_arrived_ts, 4 coordinate cols) is moot: Card
        # #37409 computes OTA from entirely different, existing columns (see evidence). The
        # stale "status=2" base_population is corrected to the real order_status predicate.
        "month_basis": "calendar month of o_completed_ts (order completion month)",
        "base_population": (
            "completed (dim_pnm_orders.order_status='completed'), intra-city "
            "(dim_pnm_orders.shifting_type='intra_city'), NON-Nano (package_name NOT ILIKE "
            "'Nano%') orders from PROD_ELDORIA.CORE.FACT_PNM_ORDERS + DIM_PNM_ORDERS, filtered "
            "to the requested o_completed_ts month"
        ),
        "source_desc": (
            "PnM MBR catalog §ota — mirrors Metabase card #37409 (\"On Time Arrival %\"), "
            "owner-ruled 2026-09-04 (owner-ruling:2026-09-04) as the correct OTA definition"
        ),
        "computed_desc": (
            "live at query time from PROD_ELDORIA.CORE.FACT_PNM_ORDERS/DIM_PNM_ORDERS + "
            "PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS/SR_LOCATION_DETAILS"
        ),
        "verify_flags": [],
        "quirks": [
            "On-time requires BOTH the 30-minute clock (shifting_ts -> latest ShiftingStarted "
            "supervisor action) AND a 2 km distance test (pickup location -> that action's GPS) "
            "— not 500 m, which is a DIFFERENT governed definition (pnm_ota_capacity, PNM-T-100a) "
            "the owner did not adopt here.",
            "Orders with no ShiftingStarted action at all are bucketed 'Unset', not folded into "
            "'Delay' and not published as 0% — they stay in ota_total_completed_orders (the "
            "denominator) but are excluded from ota_pct's numerator. Contrast PNM-G-094, where "
            "two OTHER governed models DO silently publish absent data as a bad outcome.",
            "Adapted from the card's DEV_ELDORIA.RAW tables to PROD_ELDORIA.RAW — confirmed "
            "byte-identical row counts (67,856,125 / 11,821,346) and MAX(event/created ts) on "
            "2026-09-04; a schema substitution, not a definition change.",
            "pickup_location is deduped via QUALIFY ROW_NUMBER() PARTITION BY sr_id ORDER BY id "
            "DESC (latest row wins); the ShiftingStarted action is deduped via RANK() PARTITION "
            "BY order_id, action ORDER BY event_ts_ist DESC, rk=1 — same RANK()-not-ROW_NUMBER() "
            "tie risk noted at PNM-G-096 for the two dbt-layer definitions.",
            "ota_delay_gt_60_mins_pct and ota_delay_orders/ota_delay_gt_60_mins_orders are NOT "
            "mutually exclusive slices of the same 100% — 'Delay' is a group_type bucket (< 30 "
            "min+2km failed) while >=60 min is a separate delay_minutes threshold; an order can "
            "be Delay without being >=60 min.",
        ],
        "evidence": [
            "MIRRORS Metabase card #37409 (\"On Time Arrival %\"). Verified live 2026-09-04 for "
            "7 months (2025-10 to 2026-04): ota_pct 86.93%-91.49%, ota_unset_orders 13-96 "
            "(<0.3% of the base each month), ota_delay_gt_60_mins_pct 3.6%-6.0% — sane, stable.",
            "Underlying tables confirmed to exist with the exact columns the card reads: "
            "PROD_ELDORIA.RAW.PNM_APPLICATION_SR_LOCATION_DETAILS (LOCATION GEOGRAPHY, "
            "LOCATION_TYPE, SR_ID, ID) and PROD_ELDORIA.RAW.PNM_APPLICATION_SUPERVISOR_ACTIONS "
            "(ORDER_ID, ACTION, EVENT_TS_IST, LOCATION GEOGRAPHY) — live INFORMATION_SCHEMA read, "
            "2026-09-04.",
            "SUPERSEDES the earlier blocked_reason's six-column claim (scheduled_pickup_ts, "
            "vendor_arrived_ts, 4 coordinate columns) — those columns genuinely don't exist, but "
            "that was never the only way to build OTA; Card #37409 answers the same question from "
            "different, existing columns. The old evidence is preserved in GAPS.md (PNM-G-043), "
            "not silently dropped.",
        ],
    },
    "gac_ctr": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of OPPORTUNITIES.created_at, shifted +5h30m to IST",
        "base_population": (
            "intra-city opportunities (PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES.shifting_type"
            "='intra_city') created in the requested month"
        ),
        "source_desc": (
            "PnM MBR catalog §gac_ctr — mirrors the MBR automation's Get-a-Call CTR section "
            "(repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": (
            "live at query time from PROD_CURATED.PNM_APPLICATION.OPPORTUNITIES + "
            "OPPORTUNITIES_LATEST_LSM_SCORE"
        ),
        "verify_flags": [
            "opportunity_latest_score = 999 as the 'Get a Call requested' sentinel is taken as "
            "given from the automation, not independently documented elsewhere — PNM-G-071.",
        ],
        "quirks": [
            "A GAC request is detected purely by a matching OPPORTUNITIES_LATEST_LSM_SCORE row "
            "with score = 999 — no separate 'GAC requested' flag exists on OPPORTUNITIES itself.",
            "created_at is UTC and is shifted +5h30m in SQL to get the IST month — same convention "
            "as tpo/tpo_trend, different from PNM_EXPERIENCE's already-IST timestamps.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's gac_ctr_metrics CTE exactly (PNM-S-060), structure-only "
            "adapted to a single month per the D7 pattern. Live-reconciled exact for 2026-05 "
            "(10.54%) against the automation's own open-ended query — DECISION_LOG:V6.",
        ],
    },
    "weekend": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_EXPERIENCE.shifting_ts_ist",
        "base_population": (
            "orders with a vendor assigned (vendor_id IS NOT NULL), PnM crn (crn ILIKE 'PNM%'), "
            "non-Nano (package_name NOT ILIKE 'nano%')"
        ),
        "source_desc": (
            "PnM MBR catalog §weekend — mirrors the MBR automation's weekend-order-contribution "
            "section (repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_EXPERIENCE + PROD_ELDORIA.CORE.FACT_PNM_ORDERS",
        "verify_flags": [],
        "quirks": [
            "Weekend = DAYOFWEEK(shifting_ts_ist) IN (0,6) — Snowflake's DAYOFWEEK is Sun=0..Sat=6, "
            "so this is Sunday and Saturday. The automation replaced an older PROD_CURATED-based "
            "version 2026-07-15 that used a different (buggy) day-of-week function.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's weekend_metrics CTE exactly (PNM-S-060). Live-reconciled "
            "2026-05: 43.12%, within the automation's own documented ~32-51% range.",
        ],
    },
    "cac_post_trip": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_EXPERIENCE.SHIFTING_TS_IST",
        "base_population": "intra-city, non-Nano orders from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "source_desc": (
            "PnM MBR catalog §cac_post_trip — mirrors the MBR automation's CAC-post-trip-started "
            "section (repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_EXPERIENCE + PROD_CURATED.PNM_APPLICATION.CANCELLED_ORDER_EVENTS",
        "verify_flags": [],
        "quirks": [
            "CAC = Customer-cancelled After trip started Confirmed: TRIP_STARTED_TS_IST IS NOT NULL, "
            "ORDER_STATUS='cancelled', and CANCELLED_ORDER_EVENTS.CANCELLED_BY='Customer'. The "
            "join to CANCELLED_ORDER_EVENTS is LEFT — orders with no cancellation event never "
            "match the numerator condition.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's cac_post_trip_started_metrics CTE exactly (PNM-S-060). "
            "Live-reconciled 2026-05: 2.37% — sane.",
        ],
    },
    "vendor_earnings_pctl": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_FARE_MOVEMENT.order_updated_at_ist",
        "base_population": (
            "completed, non-Nano intracity orders from PROD_ELDORIA.MART.PNM_FARE_MOVEMENT, "
            "grouped by vendor_id"
        ),
        "source_desc": (
            "PnM MBR catalog §vendor_earnings_pctl — mirrors the MBR automation's "
            "vendor-earnings-percentiles section (repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_FARE_MOVEMENT",
        "verify_flags": [],
        "quirks": [
            "Percentiles are taken over PER-VENDOR aggregates (one row per vendor_id after summing "
            "that vendor's orders/earnings for the month), not over individual orders.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's vendor_metrics_calc CTE exactly (PNM-S-060). Live-reconciled "
            "2026-05: 2,126 active vendors, 45,413 orders — matches TPO's orders_base (45,414) for "
            "the same month almost exactly, a real cross-check between two independently-sourced "
            "sections.",
        ],
    },
    "allocation": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_ALLOCATION.shifting_ts_ist",
        "base_population": "intra-city orders (shifting_type='intra_city') from PROD_ELDORIA.MART.PNM_ALLOCATION",
        "source_desc": (
            "PnM MBR catalog §allocation — mirrors the MBR automation's allocation-quality section "
            "(repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql), the largest single group (33 metrics)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_ALLOCATION",
        "verify_flags": [],
        "quirks": [
            "Most sub-metrics split by order_bucket ('SPOT' vs 'SCHEDULED') and additionally filter "
            "is_nano_order=0, is_test_user=0 — but the top-line allocation_pct/deallocation_pct do "
            "NOT apply the nano/test filters, an asymmetry copied verbatim from the automation.",
            "CAC/PAC/PoAC (cancellation_type) percentages are SPOT/SCHEDULED splits only — no "
            "overall CAC/PAC/PoAC metric exists in this section.",
            "allocation_time_p80_within_2days_minutes restricts to orders where "
            "datediff('day', order_created_ts_ist, shifting_ts_ist) <= 2 — a same/next/2-day-out "
            "booking-lead-time subset, not a duration threshold.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's allocation_metrics CTE exactly (PNM-S-060). Live-reconciled "
            "2026-05, all 33 columns execute and return sane values: allocation_pct 97.14%, "
            "completion_pct 84.68%, allocation_time_p80_minutes 41.",
        ],
    },
    "wallet": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of VENDOR_WALLET_WITHDRAWAL.CREATED_AT (withdrawals) / PAYMENT_LINKS.created_at (recharges)",
        "base_population": (
            "vendor owners with a PnM vendor_id (in PROD_ELDORIA.CORE.DIM_PNM_VENDOR) whose "
            "VENDOR_ALLOCATION_CONFIGS excludes Labour/Helper service types and 3 named package ids"
        ),
        "source_desc": (
            "PnM MBR catalog §wallet — mirrors the MBR automation's wallet-withdrawal/recharge "
            "section (repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": (
            "live at query time from PROD_CURATED.PNM_APPLICATION.VENDOR_OWNERS + "
            "VENDOR_WALLET_WITHDRAWAL + PAYMENT_LINKS + VENDOR_ALLOCATION_CONFIGS"
        ),
        "verify_flags": [],
        "quirks": [
            "Withdrawals and recharges are two INDEPENDENT queries with no shared filter beyond "
            "'same month' — a vendor with a withdrawal but no recharge (or vice versa) still counts "
            "in whichever half applies.",
            "The VENDOR_ALLOCATION_CONFIGS EXISTS filter (excluding Labour/Helper service types and "
            "3 package ids) applies ONLY to withdrawals, not recharges — copied verbatim from the "
            "automation, whose own note confirms `vac.VENDOR_ID = v.ID` is correct as written, "
            "not a bug.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's wallet_withdrawals/wallet_recharges CTEs exactly (PNM-S-060). "
            "Live-reconciled 2026-05: 4.68 withdrawals/vendor, 3.62% withdrawal failure — sane.",
        ],
    },
    "vendor_tpo_top5": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of allocation completion (RAW.pnm_application_order_allocation_infos.completed_ts_ist)",
        "base_population": (
            "distinct PnM crns with an active completed allocation in the month, NON-Nano, "
            "intra-city — from PROD_ELDORIA.RAW.pnm_application_orders/order_allocation_infos/"
            "shifting_requirements, a SEPARATE table set from this catalog's own `tpo` section "
            "(which reads PROD_CURATED, not PROD_ELDORIA.RAW)"
        ),
        "source_desc": (
            "PnM MBR catalog §vendor_tpo_top5 — mirrors the MBR automation's vendor-TPO/"
            "top-5-issues section (repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql), "
            "a pipeline distinct from this catalog's own `tpo` section"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.RAW.pnm_application_* + PROD_ELDORIA.RAW.sfms_public_hs_tickets",
        "verify_flags": [],
        "quirks": [
            "The top-5-issues percentage's denominator is total_tpo_overall (TPO off ALL tickets), "
            "NOT vendor_tpo (TPO off only vendor-raised tickets) — i.e. each issue's % answers "
            "'what share of OVERALL TPO does this vendor-raised issue represent', not 'what share "
            "of vendor tickets'. The automation's own note says this denominator choice was an "
            "explicit owner correction on 2026-07-06.",
            "Only 5 named issues are surfaced (Changes in order requirement, Supervisor Reject "
            "order, Cancellation, Customer Unreachable, Payment related) — other vendor-raised "
            "issues exist in the data but are not emitted as metrics.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's tpo_metrics CTE exactly (PNM-S-060). Live-reconciled "
            "2026-05: vendor_tpo 0.2989 — matches this catalog's own DIFFERENT `tpo` section's "
            "`tpo_vendor_raised` (0.2988, V3) almost exactly, despite reading a completely "
            "different table set. A real, non-tautological cross-check.",
        ],
    },
    "addon": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_EXPERIENCE.ORDER_CREATED_TS_IST",
        "base_population": "intra-city orders from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "source_desc": (
            "PnM MBR catalog §addon — mirrors the MBR automation's add-on-adoption section "
            "(repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "verify_flags": [],
        "quirks": [
            "⚠ DELIBERATELY has NO `order_status = 'completed'` or `package_name NOT ILIKE 'Nano%'` "
            "filter — every other PNM_EXPERIENCE section here has both. The automation's own note "
            "confirms this is intentional: adding those filters raises the overall adoption % from "
            "~86-89% to ~97-98%, a real difference, not a bug to fix.",
            "Add-on categories are detected via LOWER(ADD_ONS) LIKE substring matches on a "
            "free-text-ish column — a category is not mutually exclusive with the others.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's addon_metrics CTE exactly (PNM-S-060). Live-reconciled "
            "2026-05: pct_orders_with_any_addon 87.86% — within the automation's own documented "
            "~86-89% range.",
        ],
    },
    "completion": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_EXPERIENCE.shifting_ts_ist",
        "base_population": "non-Nano, intra-city orders from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "source_desc": (
            "PnM MBR catalog §completion — mirrors the MBR automation's completion-score/NPS/"
            "detractors section (repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "verify_flags": [],
        "quirks": [
            "completion_score_pct's denominator is orders WITH A VENDOR ASSIGNED (vendor_id IS NOT "
            "NULL), not all orders in the population — a narrower base than detractor_pct's, which "
            "denominates on completed orders.",
            "nps is Promoter% minus Detractor%, both computed over completed orders with a non-null "
            "classification — Neutral orders count in the denominator but neither numerator.",
            "Fixed a trailing-comma syntax error present in the automation's own original SQL "
            "(owner-confirmed as a typo, not a definition change).",
        ],
        "evidence": [
            "MIRRORS the MBR automation's completion_metrics CTE exactly (PNM-S-060). Live-reconciled "
            "2026-05: completion_score_pct 86.23%, nps 75.06, detractor_pct 4.25% — sane.",
        ],
    },
    "fare": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": (
            "calendar month of PNM_FARE_MOVEMENT.order_created_month (counts/surge/timing metrics) "
            "OR order_updated_at_ist (AOV/coupon %) — two DIFFERENT month bases in one section, "
            "see quirks"
        ),
        "base_population": "intracity orders from PROD_ELDORIA.MART.PNM_FARE_MOVEMENT",
        "source_desc": (
            "PnM MBR catalog §fare — mirrors the MBR automation's fare/coupon/surge section "
            "(repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_FARE_MOVEMENT",
        "verify_flags": [],
        "quirks": [
            "⚠ Computed as TWO independently-filtered sub-queries UNIONed and MAX()-aggregated: one "
            "on `order_created_month` (total_orders, surge counts/%, shifting-started counts, fare "
            "increase/decrease stats) with NO completed/non-Nano/test-user filter; the other on "
            "`order_updated_at_ist` (aov, pct_orders_with_coupon) WITH completed + non-Nano + "
            "non-test filters. Each metric therefore has a DIFFERENT population than its neighbors "
            "in this same section — this is copied verbatim from the automation, not simplified, "
            "because collapsing to one filter would change what each metric measures.",
            "aov and pct_orders_with_coupon use a slightly different Nano exclusion form "
            "(`package_name NOT IN (3 literal names)`) than every other section's "
            "`NOT ILIKE 'Nano%'` — also copied verbatim.",
        ],
        "evidence": [
            "MIRRORS the MBR automation's fare_metrics CTE exactly (PNM-S-060), including its "
            "two-way UNION/MAX() structure. Live-reconciled 2026-05: total_orders 58,821, AOV "
            "₹6,261, 75.09% of orders carry surge, 11.99% carry a coupon — sane.",
        ],
    },
    "vendor_earnings_bucket": {
        "built": True,
        "readiness": "prototype_only",
        "month_basis": "calendar month of PNM_EXPERIENCE.order_completed_ts_ist",
        "base_population": "completed, non-Nano, intra-city orders from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "source_desc": (
            "PnM MBR catalog §vendor_earnings_bucket — mirrors the MBR automation's "
            "vendor-earnings-distribution-by-bucket section "
            "(repo@0deb488:reference/mbr_automation_dev_ingestion_v12.sql)"
        ),
        "computed_desc": "live at query time from PROD_ELDORIA.MART.PNM_EXPERIENCE",
        "verify_flags": [],
        "quirks": [
            "One Argus/MBR metric name decomposes into 5 catalog metric ids, one per vendor bucket "
            "(GoldPlus/Gold/Silver/Bronze/New) — missing bucket_type is COALESCEd to 'New'.",
            "Revenue is attributed using each VENDOR's single LATEST bucket in the month (by "
            "order_completed_ts_ist DESC, order_id DESC as tiebreak), applied to ALL of that "
            "vendor's orders in the month — NOT each order's own bucket at its own completion time. "
            "A vendor who was promoted mid-month has their entire month's revenue counted under "
            "their end-of-month bucket.",
            "The 5 percentages sum to 100% by construction (SUM(...) OVER () with no partition, "
            "since this is already scoped to one month) — verified live 2026-05 (47.08+13.46+10.05"
            "+23.06+6.35 = 100.00).",
        ],
        "evidence": [
            "MIRRORS the MBR automation's vendor_earnings_bucket_metrics CTE exactly (PNM-S-060). "
            "Live-reconciled 2026-05: GoldPlus 47.08%, Gold 13.46%, Silver 10.05%, Bronze 23.06%, "
            "New 6.35% — sums to 100.00, sane.",
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
    "leads_overall_intra_city":  {"section": "leads", "unit": "leads", "source": "sql",
                       "definition": "Distinct PnM opportunities (booking-funnel leads) created in the month, intra-city shifts only. Governed pnm_overall_leads covers all shifting types and will not match this figure (PNM-G-090).",
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
                           "numerator": "orders_overall", "denominator": "leads_overall_intra_city", "scale": 100,
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

    # ── ota (On Time Arrival — Metabase card #37409, owner-ruled 2026-09-04) ──
    # 30 min AND 2 km, anchored on the latest ShiftingStarted supervisor action.
    # All source:"sql" — the card computes every value directly, like order_edits.
    "ota_total_completed_orders": {"section": "ota", "unit": "orders", "source": "sql",
        "definition": "Completed, non-Nano, intra-city orders in the month (the OTA denominator).",
        "aliases": ["ota base", "ota order base", "ota denominator", "orders in the ota base",
                    "how many orders in the ota base", "total completed orders for ota"]},
    "ota_on_time_orders": {"section": "ota", "unit": "orders", "source": "sql",
        "definition": "Orders where the ShiftingStarted supervisor action occurred within 30 minutes of shifting_ts AND within 2 km of the pickup location.",
        "aliases": ["on time orders", "orders on time", "how many orders were on time"]},
    "ota_unset_orders": {"section": "ota", "unit": "orders", "source": "sql",
        "definition": "Completed orders with NO ShiftingStarted supervisor action recorded at all — excluded from ota_pct's numerator, not counted as delayed.",
        "aliases": ["unset ota orders", "orders with no shifting started event", "ota unset"]},
    "ota_delay_orders": {"section": "ota", "unit": "orders", "source": "sql",
        "definition": "Completed orders that failed the 30-min/2km on-time test (excludes ota_unset_orders, which is its own bucket).",
        "aliases": ["delayed orders", "orders delayed", "how many orders were delayed"]},
    "ota_delay_gt_60_mins_orders": {"section": "ota", "unit": "orders", "source": "sql",
        "definition": "Completed orders where the ShiftingStarted action was 60+ minutes after shifting_ts (a delay_minutes threshold, independent of the 2 km distance test).",
        "aliases": ["orders delayed more than 60 minutes", "orders delayed over 60 minutes",
                    "orders delayed by more than an hour"]},
    "ota_delay_gt_60_mins_pct": {"section": "ota", "unit": "%", "source": "sql",
        "definition": "% of completed orders delayed 60+ minutes (ota_delay_gt_60_mins_orders ÷ ota_total_completed_orders).",
        "aliases": ["percent orders delayed more than 60 minutes", "percent orders delayed over 60 minutes",
                    "delay rate over 60 minutes", "share of orders delayed more than an hour"]},
    "ota_pct": {"section": "ota", "unit": "%", "source": "sql",
        "definition": "On-Time Arrival %: on-time orders (30 min AND 2 km) ÷ completed non-Nano intra-city orders. Excludes ota_unset_orders from the numerator.",
        "aliases": ["ota", "ota percentage", "on time arrival", "on time arrival percentage",
                    "on time arrival rate", "on-time arrival %"]},

    # ── gac_ctr (Get a Call CTR — mirrors the MBR automation, PNM-S-060) ──
    "gac_ctr_pct": {"section": "gac_ctr", "unit": "%", "source": "sql",
        "definition": "Get-a-Call click-through rate: intra-city opportunities with a GAC request (OPPORTUNITIES_LATEST_LSM_SCORE.opportunity_latest_score = 999) ÷ all intra-city opportunities in the month.",
        "aliases": ["get a call ctr", "get a call click through rate", "gac ctr",
                    "get a call rate", "gac click through rate"]},

    # ── weekend (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "weekend_order_share_pct": {"section": "weekend", "unit": "%", "source": "sql",
        "definition": "% of orders (with a vendor assigned) whose shifting_ts_ist falls on a Saturday or Sunday.",
        "aliases": ["weekend order contribution", "weekend order share", "percent orders on weekend",
                    "weekend contribution"]},

    # ── cac_post_trip (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "cac_post_trip_started_pct": {"section": "cac_post_trip", "unit": "%", "source": "sql",
        "definition": "% of orders customer-cancelled AFTER the trip had already started (TRIP_STARTED_TS_IST not null, order_status='cancelled', cancelled_by='Customer').",
        "aliases": ["cac post trip started", "customer cancelled after trip started",
                    "cac after trip start", "post trip cancellation rate"]},

    # ── vendor_earnings_pctl (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "active_vendor_count": {"section": "vendor_earnings_pctl", "unit": "vendors", "source": "sql",
        "definition": "Distinct vendors with at least one completed, non-Nano, intracity order in the month.",
        "aliases": ["active vendors", "how many active vendors", "number of active vendors"]},
    "total_order_count": {"section": "vendor_earnings_pctl", "unit": "orders", "source": "sql",
        "definition": "Completed, non-Nano, intracity orders in the month (the vendor-earnings-percentile denominator population).",
        "aliases": ["vendor earnings total orders"]},
    "p50_earnings_per_vendor": {"section": "vendor_earnings_pctl", "unit": "currency", "source": "sql",
        "definition": "Median (P50) total fare earned per active vendor in the month. --metric only: any phrasing containing 'p50' or 'median' hits the UNSUPPORTED_TERMS guard, same reason p50_trip_duration is hidden (D10).",
        "aliases": []},
    "p80_earnings_per_vendor": {"section": "vendor_earnings_pctl", "unit": "currency", "source": "sql",
        "definition": "P80 total fare earned per active vendor in the month. --metric only: 'per vendor' hits the UNSUPPORTED_TERMS no-vendor-cuts guard, even though this is an aggregate stat, not a cut.",
        "aliases": []},
    "p50_orders_per_vendor": {"section": "vendor_earnings_pctl", "unit": "orders", "source": "sql",
        "definition": "Median (P50) completed orders per active vendor in the month. --metric only: both 'p50'/'median' and 'per vendor' hit UNSUPPORTED_TERMS.",
        "aliases": []},
    "p80_orders_per_vendor": {"section": "vendor_earnings_pctl", "unit": "orders", "source": "sql",
        "definition": "P80 completed orders per active vendor in the month. --metric only: 'per vendor' hits the UNSUPPORTED_TERMS no-vendor-cuts guard.",
        "aliases": []},

    # ── allocation (mirrors the MBR automation, PNM-S-060, PNM-G-071 — 33 metrics) ──
    "alloc_total_orders": {"section": "allocation", "unit": "orders", "source": "sql",
        "definition": "Intra-city orders from PNM_ALLOCATION in the month (renamed from the automation's bare 'total_orders' to avoid colliding with the fare section's id of the same name).",
        "aliases": ["allocation total orders", "total orders in allocation base"]},
    "allocated_orders": {"section": "allocation", "unit": "orders", "source": "sql",
        "definition": "Orders successfully allocated to a vendor (is_allocated=1).",
        "aliases": ["how many orders were allocated", "allocated order count"]},
    "allocation_pct": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of orders successfully allocated to a vendor.",
        "aliases": ["allocation rate", "allocation percentage", "percent orders allocated"]},
    "total_spot_orders": {"section": "allocation", "unit": "orders", "source": "sql",
        "definition": "Orders in the SPOT bucket (order_bucket='SPOT').",
        "aliases": ["spot orders", "how many spot orders", "total spot orders"]},
    "allocation_pct_spot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of SPOT orders successfully allocated.",
        "aliases": ["spot allocation rate", "spot allocation percentage", "allocation rate for spot orders"]},
    "total_scheduled_orders": {"section": "allocation", "unit": "orders", "source": "sql",
        "definition": "Orders in the SCHEDULED bucket (order_bucket='SCHEDULED').",
        "aliases": ["scheduled orders", "how many scheduled orders", "total scheduled orders"]},
    "allocation_pct_scheduled": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of SCHEDULED orders successfully allocated.",
        "aliases": ["scheduled allocation rate", "scheduled allocation percentage"]},
    "allocation_share_via_engine_pct": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "Of SPOT, non-Nano, non-test orders allocated via Engine or Open Pool, the % via Engine.",
        "aliases": ["allocation share via engine", "percent allocated via engine", "engine allocation share"]},
    "allocation_share_via_open_pool_pct": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "Of SPOT, non-Nano, non-test orders allocated via Engine or Open Pool, the % via Open Pool.",
        "aliases": ["allocation share via open pool", "percent allocated via open pool", "open pool allocation share"]},
    "deallocation_pct": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of orders deallocated after a vendor had already accepted (is_deallocated_post_accept=1).",
        "aliases": ["deallocation rate", "deallocation percentage", "percent orders deallocated"]},
    "deallocation_pct_spot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "Deallocation rate restricted to SPOT orders.",
        "aliases": ["spot deallocation rate", "deallocation rate for spot orders"]},
    "deallocation_pct_scheduled": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "Deallocation rate restricted to SCHEDULED orders.",
        "aliases": ["scheduled deallocation rate", "deallocation rate for scheduled orders"]},
    "completion_pct": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of non-Nano, non-test orders that reached order_status='completed'.",
        "aliases": ["allocation completion rate", "completion percentage", "percent orders completed"]},
    "completion_pct_spot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "Completion rate restricted to SPOT, non-Nano, non-test orders.",
        "aliases": ["spot completion rate", "completion rate for spot orders"]},
    "completion_pct_scheduled": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "Completion rate restricted to SCHEDULED, non-Nano, non-test orders.",
        "aliases": ["scheduled completion rate", "completion rate for scheduled orders"]},
    "dry_run_p75_kms_spot": {"section": "allocation", "unit": "km", "source": "sql",
        "definition": "P75 of dry-run distance (km) for SPOT, non-Nano, non-test orders.",
        "aliases": ["p75 dry run distance", "dry run distance p75", "p75 dry run kms spot"]},
    "cac_pct_spot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of SPOT, non-Nano, non-test orders cancelled with cancellation_type='CAC' (customer, after accept).",
        "aliases": ["cac percentage spot", "cac rate spot orders"]},
    "pac_pct_spot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of SPOT, non-Nano, non-test orders cancelled with cancellation_type='PAC' (partner/vendor, after accept).",
        "aliases": ["pac percentage spot", "pac rate spot orders"]},
    "poac_pct_spot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of SPOT, non-Nano, non-test orders cancelled with cancellation_type='PoAC' (post-acceptance-other-cancellation).",
        "aliases": ["poac percentage spot", "poac rate spot orders"]},
    "cac_pct_scheduled": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "CAC cancellation rate restricted to SCHEDULED, non-Nano, non-test orders.",
        "aliases": ["cac percentage scheduled", "cac rate scheduled orders"]},
    "pac_pct_scheduled": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "PAC cancellation rate restricted to SCHEDULED, non-Nano, non-test orders.",
        "aliases": ["pac percentage scheduled", "pac rate scheduled orders"]},
    "poac_pct_scheduled": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "PoAC cancellation rate restricted to SCHEDULED, non-Nano, non-test orders.",
        "aliases": ["poac percentage scheduled", "poac rate scheduled orders"]},
    "allocation_time_p80_minutes": {"section": "allocation", "unit": "minutes", "source": "sql",
        "definition": "P80 of allocation_tat_minutes across all allocated orders.",
        "aliases": ["allocation time p80", "p80 allocation time", "allocation tat p80"]},
    "allocation_time_p80_spot_minutes": {"section": "allocation", "unit": "minutes", "source": "sql",
        "definition": "P80 of allocation_tat_minutes restricted to SPOT, allocated orders.",
        "aliases": ["spot allocation time p80", "p80 allocation time spot"]},
    "allocation_time_p80_within_2days_minutes": {"section": "allocation", "unit": "minutes", "source": "sql",
        "definition": "P80 of allocation_tat_minutes restricted to allocated orders booked within 2 days of the shift date (datediff(day, order_created_ts_ist, shifting_ts_ist) <= 2).",
        "aliases": ["allocation time p80 within 2 days", "p80 allocation time near-term bookings"]},
    "pct_no_vendor_before_slot": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of orders with no_vendor_before_slot=1 — no vendor was found before the scheduled slot.",
        "aliases": ["percent no vendor before slot", "no vendor before slot rate"]},
    "pct_supervisor_changed": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of completed, non-Nano, non-test orders where the supervisor changed at some point (is_supervisor_changed=1).",
        "aliases": ["percent supervisor changed", "supervisor change rate"]},
    "pct_supervisor_changed_post_trip": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of completed, non-Nano, non-test orders where the supervisor changed AFTER the trip started.",
        "aliases": ["percent supervisor changed post trip", "supervisor change rate after trip start"]},
    "p80_pickup_km_deviation": {"section": "allocation", "unit": "km", "source": "sql",
        "definition": "P80 of pickup_km_deviation for completed, non-Nano, non-test orders.",
        "aliases": ["p80 pickup km deviation", "pickup deviation p80"]},
    "p80_drop_km_deviation": {"section": "allocation", "unit": "km", "source": "sql",
        "definition": "P80 of drop_km_deviation for completed, non-Nano, non-test orders.",
        "aliases": ["p80 drop km deviation", "drop deviation p80"]},
    "orders_with_more_than_2_deallocations": {"section": "allocation", "unit": "orders", "source": "sql",
        "definition": "Orders deallocated more than twice (deallocation_count > 2).",
        "aliases": ["orders with more than 2 deallocations", "orders deallocated over 2 times"]},
    "pct_orders_with_more_than_2_deallocations": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of orders deallocated more than twice.",
        "aliases": ["percent orders with more than 2 deallocations"]},
    "reschedule_pct": {"section": "allocation", "unit": "%", "source": "sql",
        "definition": "% of non-Nano, non-test orders with a non-null last_rescheduled_shift_ts — the shift date was changed at least once.",
        "aliases": ["reschedule rate", "reschedule percentage", "percent orders rescheduled"]},

    # ── wallet (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "withdrawals_per_vendor": {"section": "wallet", "unit": "count", "source": "sql",
        "definition": "Wallet withdrawal requests ÷ distinct vendor owners requesting them, in the month. --metric only: 'per vendor' hits the UNSUPPORTED_TERMS no-vendor-cuts guard.",
        "aliases": []},
    "p50_withdrawal_amount": {"section": "wallet", "unit": "currency", "source": "sql",
        "definition": "Median (P50) wallet withdrawal amount in the month. --metric only: same 'p50'/'median' guard conflict as p50_earnings_per_vendor.",
        "aliases": []},
    "withdrawal_failure_pct": {"section": "wallet", "unit": "%", "source": "sql",
        "definition": "% of wallet withdrawal requests with status='Failure'.",
        "aliases": ["withdrawal failure rate", "withdrawal failure percentage"]},
    "recharges_per_vendor": {"section": "wallet", "unit": "count", "source": "sql",
        "definition": "Wallet recharge payment links ÷ distinct vendor owners requesting them, in the month. --metric only: 'per vendor' hits the UNSUPPORTED_TERMS no-vendor-cuts guard.",
        "aliases": []},
    "p50_recharge_amount": {"section": "wallet", "unit": "currency", "source": "sql",
        "definition": "Median (P50) wallet recharge amount in the month. --metric only: same 'p50'/'median' guard conflict as p50_earnings_per_vendor.",
        "aliases": []},
    "recharge_failure_pct": {"section": "wallet", "unit": "%", "source": "sql",
        "definition": "% of wallet recharge payment links with status=2 (failed).",
        "aliases": ["recharge failure rate", "recharge failure percentage"]},

    # ── vendor_tpo_top5 (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "vendor_tpo": {"section": "vendor_tpo_top5", "unit": "ratio", "source": "sql",
        "definition": "Vendor-raised tickets ÷ completed orders in the month, from the RAW-table TPO pipeline (distinct from this catalog's own tpo_vendor_raised).",
        "aliases": ["vendor tpo raw", "vendor raised tpo raw pipeline"]},
    "l1_top5_issues_vendor_raised_changes_in_order_requirement": {"section": "vendor_tpo_top5", "unit": "%", "source": "sql",
        "definition": "Share of OVERALL TPO (all tickets) attributable to vendor-raised 'Changes in order requirement' tickets.",
        "aliases": ["top issue changes in order requirement", "vendor issue changes in order requirement"]},
    "l1_top5_issues_vendor_raised_supervisor_reject_order": {"section": "vendor_tpo_top5", "unit": "%", "source": "sql",
        "definition": "Share of OVERALL TPO attributable to vendor-raised 'Supervisor Reject order' tickets.",
        "aliases": ["top issue supervisor reject order", "vendor issue supervisor reject order"]},
    "l1_top5_issues_vendor_raised_cancellation": {"section": "vendor_tpo_top5", "unit": "%", "source": "sql",
        "definition": "Share of OVERALL TPO attributable to vendor-raised 'Cancellation' tickets.",
        "aliases": ["top issue cancellation vendor raised", "vendor issue cancellation"]},
    "l1_top5_issues_vendor_raised_customer_unreachable": {"section": "vendor_tpo_top5", "unit": "%", "source": "sql",
        "definition": "Share of OVERALL TPO attributable to vendor-raised 'Customer Unreachable' tickets.",
        "aliases": ["top issue customer unreachable", "vendor issue customer unreachable"]},
    "l1_top5_issues_vendor_raised_payment_related": {"section": "vendor_tpo_top5", "unit": "%", "source": "sql",
        "definition": "Share of OVERALL TPO attributable to vendor-raised 'Payment related' tickets.",
        "aliases": ["top issue payment related", "vendor issue payment related"]},

    # ── addon (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "pct_orders_with_any_addon": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders (no completed/Nano filter — see section quirks) with any non-empty ADD_ONS value.",
        "aliases": ["overall add-on adoption", "percent orders with any addon", "addon adoption rate"]},
    "pct_orders_with_packing": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders with a packing-related add-on (single- or multi-layer packing).",
        "aliases": ["packing addon adoption", "percent orders with packing addon"]},
    "pct_orders_with_ac": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders with an AC installation/uninstallation add-on.",
        "aliases": ["ac addon adoption", "percent orders with ac addon"]},
    "pct_orders_with_carpentry": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders with a carpentry-related add-on (professional carpenter or dismantling/reassembly).",
        "aliases": ["carpentry addon adoption", "percent orders with carpentry addon"]},
    "pct_orders_with_rope_pulling": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders with a rope-pulling add-on.",
        "aliases": ["rope pulling addon adoption", "percent orders with rope pulling addon"]},
    "pct_orders_with_bigger_vehicle": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders with a bigger-vehicle add-on.",
        "aliases": ["bigger vehicle addon adoption", "percent orders with bigger vehicle addon"]},
    "pct_orders_with_extra_labour": {"section": "addon", "unit": "%", "source": "sql",
        "definition": "% of orders with an extra-labour add-on.",
        "aliases": ["extra labour addon adoption", "percent orders with extra labour addon"]},

    # ── completion (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "completion_score_pct": {"section": "completion", "unit": "%", "source": "sql",
        "definition": "% of vendor-assigned, non-Nano, intra-city orders that reached order_status='completed'.",
        "aliases": ["overall completion score", "completion score", "completion score percentage"]},
    "nps": {"section": "completion", "unit": "score", "source": "sql",
        "definition": "Net Promoter Score over completed orders with a non-null classification: %Promoter − %Detractor.",
        "aliases": ["overall nps", "net promoter score", "nps score"]},
    "detractor_pct": {"section": "completion", "unit": "%", "source": "sql",
        "definition": "% of completed orders classified as Detractor.",
        "aliases": ["overall detractors percent", "detractor percentage", "percent detractors"]},

    # ── fare (mirrors the MBR automation, PNM-S-060, PNM-G-071 — see section quirks for the two-population split) ──
    "total_orders": {"section": "fare", "unit": "orders", "source": "sql",
        "definition": "Intracity orders created in the month, from PNM_FARE_MOVEMENT (no completed/Nano/test filter — see section quirks).",
        "aliases": ["fare section total orders"]},
    "aov": {"section": "fare", "unit": "currency", "source": "sql",
        "definition": "Average order value: total fare of completed, non-Nano, non-test orders ÷ their count, on the order_updated_at_ist month.",
        "aliases": ["average order value", "aov"]},
    "no_of_orders_with_surge": {"section": "fare", "unit": "orders", "source": "sql",
        "definition": "Orders with booking_surge_multiplier not equal to 1.",
        "aliases": ["orders with surge", "number of orders with surge"]},
    "pct_orders_with_surge": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "% of orders with booking_surge_multiplier not equal to 1.",
        "aliases": ["percent orders with surge", "surge rate"]},
    "pct_orders_positive_surge": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "% of orders with booking_surge_multiplier > 1.",
        "aliases": ["percent orders positive surge", "positive surge rate"]},
    "pct_orders_negative_surge": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "% of orders with booking_surge_multiplier < 1.",
        "aliases": ["percent orders negative surge", "negative surge rate"]},
    "pct_orders_with_coupon": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "% of completed, non-Nano orders with a non-empty discount_coupon, on the order_updated_at_ist month.",
        "aliases": ["percent orders with coupon", "coupon usage rate"]},
    "orders_with_shifting_started": {"section": "fare", "unit": "orders", "source": "sql",
        "definition": "Orders with a non-null shifting_started_ts_ist.",
        "aliases": ["orders with shifting started", "count of orders shifting started"]},
    "pct_cases_with_price_change_post_shifting_start": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "Of orders with shifting started, the % with a non-zero fare_delta.",
        "aliases": ["percent price change post shifting start", "price change rate after shifting start"]},
    "pct_orders_fare_increased": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "Of orders with shifting started, the % with fare_delta > 0.",
        "aliases": ["percent orders fare increased", "fare increase rate"]},
    "median_fare_increase_amt": {"section": "fare", "unit": "currency", "source": "sql",
        "definition": "Median fare_delta among orders where fare_delta > 0. --metric only: 'median' hits the UNSUPPORTED_TERMS guard.",
        "aliases": []},
    "pct_orders_fare_decreased": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "Of orders with shifting started, the % with fare_delta < 0.",
        "aliases": ["percent orders fare decreased", "fare decrease rate"]},
    "median_fare_decrease_amt": {"section": "fare", "unit": "currency", "source": "sql",
        "definition": "Median absolute fare_delta among orders where fare_delta < 0. --metric only: 'median' hits the UNSUPPORTED_TERMS guard.",
        "aliases": []},
    "pct_edited_orders_with_fare_change": {"section": "fare", "unit": "%", "source": "sql",
        "definition": "Of orders edited post-start (is_edited_post_start=1), the % with a non-zero fare_delta.",
        "aliases": ["percent edited orders with fare change", "fare change rate for edited orders"]},

    # ── vendor_earnings_bucket (mirrors the MBR automation, PNM-S-060, PNM-G-071) ──
    "revenue_pct_goldplus": {"section": "vendor_earnings_bucket", "unit": "%", "source": "sql",
        "definition": "Share of total completed-order revenue attributed to vendors in the GoldPlus bucket (each vendor's latest bucket in the month).",
        "aliases": ["vendor earnings goldplus", "revenue share goldplus bucket"]},
    "revenue_pct_gold": {"section": "vendor_earnings_bucket", "unit": "%", "source": "sql",
        "definition": "Share of total completed-order revenue attributed to vendors in the Gold bucket.",
        "aliases": ["vendor earnings gold", "revenue share gold bucket"]},
    "revenue_pct_silver": {"section": "vendor_earnings_bucket", "unit": "%", "source": "sql",
        "definition": "Share of total completed-order revenue attributed to vendors in the Silver bucket.",
        "aliases": ["vendor earnings silver", "revenue share silver bucket"]},
    "revenue_pct_bronze": {"section": "vendor_earnings_bucket", "unit": "%", "source": "sql",
        "definition": "Share of total completed-order revenue attributed to vendors in the Bronze bucket.",
        "aliases": ["vendor earnings bronze", "revenue share bronze bucket"]},
    "revenue_pct_new": {"section": "vendor_earnings_bucket", "unit": "%", "source": "sql",
        "definition": "Share of total completed-order revenue attributed to vendors in the New bucket (includes null vendor_bucket_type).",
        "aliases": ["vendor earnings new bucket", "revenue share new bucket"]},
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
