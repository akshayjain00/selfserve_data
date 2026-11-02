-- card 44469 New Repeat Quote to Order Conversion
-- params: START_DATE=2026-08-01 END_DATE=2026-09-30 granularity='Month' order_type='completed' category='Business'; pickup/drop city blocks dropped
-- Metabase run failed: Numeric value 'XXXXXX0089' is not recognized. Literal substitution on Snowflake failed the same way ('XXXXXX4182').
-- REWRITE (PII masking): mobile keys replaced by customer keys:
--   events -> customers via c.id = ptl_fe_events.customer_id (100% match, mobile-equal on sample)
--   first-order base keyed on orders.customer_id (uuid) joined to c.uuid
--   internal users: c.uuid NOT IN (ptl_internal_users.customer_uuid)
with base as (
    SELECT customer_id, created_at + interval '330 mins' AS first_order_date
    FROM prod_curated.partload_application.orders
    WHERE orders.state = '3'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at ASC) = 1
)
select date_trunc('Month', date(e.event_timestamp)) as month,
    CASE WHEN base.first_order_date IS NULL OR DATE(e.event_timestamp) <= DATE(base.first_order_date) THEN 'new customer' ELSE 'repeat customer' END AS customer_tag,
    count(distinct case when e.event_name = 'ptlbookingdetailspage_quote_viewed' then e.app_session_id end) as quote_sessions,
    count(distinct case when e.event_name = 'ptlbookingdetailspage_booknow_clicked' AND o.state = '3' then e.app_session_id end) as book_now_sessions,
    book_now_sessions / quote_sessions as conversion_pct
from prod_curated.partload_analytics.ptl_fe_events e
LEFT JOIN prod_curated.oms_public.customers c ON c.id = e.customer_id
left join base on base.customer_id = c.uuid
left JOIN prod_curated.partload_application.orders o ON PARSE_JSON(e.variable_attr):order_id::STRING = o.external_id
where c.uuid NOT IN (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
and e.event_name in ('ptlbookingdetailspage_quote_viewed', 'ptlbookingdetailspage_booknow_clicked')
and e.app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
AND date(e.event_timestamp) >= '2026-08-01' AND date(e.event_timestamp) <= '2026-09-30'
AND (CASE WHEN c.frequency IN (1, 2, 3, 4) THEN 'Business' ELSE 'Personal' END) = 'Business'
group by 1,2
order by 1 desc;
