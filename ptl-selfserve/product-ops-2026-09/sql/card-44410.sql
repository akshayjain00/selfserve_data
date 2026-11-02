-- card 44410 Overall Conversion (VSS -> Quote -> BookNow, session-level)
-- params: START_DATE=2026-08-01 END_DATE=2026-09-30 granularity='Month' order_type='completed'; pickup/drop city blocks dropped
-- Metabase run failed: Numeric value 'XXXXXX7757' is not recognized.
-- REWRITE (PII masking): internal-user exclusion moved from customer_mobile_number NOT IN ptl_internal_users.mobile
--   to customers.uuid (via customers.id = ptl_fe_events.customer_id) NOT IN ptl_internal_users.customer_uuid. Unused base CTE and ptl_routes join dropped (no city filter).
-- NOTE: card has NO business/personal filter. :business_only toggles a supplementary business-only variant (c.frequency IN (1,2,3,4)).
select date_trunc('Month', date(e.event_timestamp)) as month,
    count(distinct case when e.event_name = 'vehicleselectionscreen_vehicles_loaded' then e.app_session_id end) as vss_sessions,
    count(distinct case when e.event_name = 'ptlbookingdetailspage_quote_viewed' then e.app_session_id end) as quote_sessions,
    count(distinct case when e.event_name = 'ptlbookingdetailspage_booknow_clicked' and o.state = '3' then e.app_session_id end) as book_now_sessions,
    book_now_sessions / nullif(vss_sessions, 0) as conversion_pct,
    book_now_sessions / nullif(quote_sessions, 0) as quote_to_order,
    quote_sessions / nullif(vss_sessions, 0) as vss_to_quote
from prod_curated.partload_analytics.ptl_fe_events e
LEFT JOIN prod_curated.partload_application.orders o ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
LEFT JOIN prod_curated.oms_public.customers c ON c.id = e.customer_id
where c.uuid not in (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
and e.event_name in ('vehicleselectionscreen_vehicles_loaded','ptlbookingdetailspage_quote_viewed', 'ptlbookingdetailspage_booknow_clicked')
and e.app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
AND date(e.event_timestamp) >= '2026-08-01' AND date(e.event_timestamp) <= '2026-09-30'
-- business-only variant: AND c.frequency IN (1,2,3,4)
group by 1 order by 1;
