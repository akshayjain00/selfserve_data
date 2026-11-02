-- Supplement to card 44469 (card has no VSS step): VSS sessions for NEW business users, same tagging/keys as card-44469.sql rewrite,
-- VSS event as in card 44410 ('vehicleselectionscreen_vehicles_loaded', no vehicle filter). Not a Metabase card.
with base as (
    SELECT customer_id, created_at + interval '330 mins' AS first_order_date
    FROM prod_curated.partload_application.orders WHERE orders.state = '3'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY created_at ASC) = 1
)
select date_trunc('Month', date(e.event_timestamp)) as month,
    CASE WHEN base.first_order_date IS NULL OR DATE(e.event_timestamp) <= DATE(base.first_order_date) THEN 'new customer' ELSE 'repeat customer' END AS customer_tag,
    count(distinct case when e.event_name = 'vehicleselectionscreen_vehicles_loaded' then e.app_session_id end) as vss_sessions,
    count(distinct case when e.event_name = 'ptlbookingdetailspage_quote_viewed' then e.app_session_id end) as quote_sessions,
    quote_sessions / vss_sessions as vss_to_quote
from prod_curated.partload_analytics.ptl_fe_events e
LEFT JOIN prod_curated.oms_public.customers c ON c.id = e.customer_id
left join base on base.customer_id = c.uuid
where c.uuid NOT IN (select customer_uuid from prod_curated.partload_analytics.ptl_internal_users where customer_uuid is not null)
and e.event_name in ('vehicleselectionscreen_vehicles_loaded','ptlbookingdetailspage_quote_viewed')
and e.app_session_id != 'dbe3759b-bd16-4523-9f24-1c0f45e34c2a'
AND date(e.event_timestamp) >= '2026-08-01' AND date(e.event_timestamp) <= '2026-09-30'
AND c.frequency IN (1, 2, 3, 4)
group by 1,2 order by 1 desc, 2;
