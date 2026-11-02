-- Blank customer_uuid on PTL Book Now taps: raw app event evidence (Oct 19–29 2026).
-- Source: PROD_CURATED.PORTER_EVENTS.LOGGED_IN_CUSTOMER_APP_EVENTS, the full logged-in customer app stream.
--   EVENT_TIMESTAMP is epoch millis UTC (+330 min = IST). CUSTOMER_UUID is a row-level column the app SDK fills;
--   VARIABLE_ATTR is the event payload the booking screen builds.
-- Finding: payload customer_uuid = '' and payload order_id = '' while the row CUSTOMER_UUID is filled.

-- 1) Every affected Book Now tap (853 rows)
select r.event_id,
       r.customer_id,
       r.customer_uuid                                           as row_customer_uuid,
       to_timestamp_ntz(r.event_timestamp/1000) + interval '330 minutes' as event_ist,
       r.application_version_name, r.device_make, r.device_model, r.device_platform_version,
       r.app_session_id,
       try_parse_json(r.variable_attr):customer_uuid::string     as payload_customer_uuid,
       try_parse_json(r.variable_attr):order_id::string          as payload_order_id,
       try_parse_json(r.variable_attr):route_id::string          as route_id,
       try_parse_json(r.variable_attr):weight_kg::string         as weight_kg,
       try_parse_json(r.variable_attr):selected_day::string      as selected_day,
       try_parse_json(r.variable_attr):pickup_slot::string       as pickup_slot,
       try_parse_json(r.variable_attr):quotation::string         as quotation,
       try_parse_json(r.variable_attr):quotation_id::string      as quotation_id,
       r.variable_attr                                           as raw_payload
from prod_curated.porter_events.logged_in_customer_app_events r
where r.event_name = 'ptlbookingdetailspage_booknow_clicked'
  and (to_timestamp_ntz(r.event_timestamp/1000) + interval '330 minutes')::date between '2026-10-19' and '2026-10-29'
  and coalesce(try_parse_json(r.variable_attr):customer_uuid::string, '') = ''
order by event_ist;

-- 2) Reconciliation against the curated PTL table: all 853 event_ids match, all blank in both
with blank as (
  select distinct event_id
  from prod_curated.partload_analytics.ptl_fe_events
  where event_name = 'ptlbookingdetailspage_booknow_clicked'
    and convert_timezone('Asia/Kolkata', event_timestamp)::date between '2026-10-19' and '2026-10-29'
    and coalesce(try_parse_json(variable_attr):customer_uuid::string, '') = ''
)
select count(distinct b.event_id) blank_events_curated,                                         -- 853
       count(distinct r.event_id) found_in_raw,                                                 -- 853
       count_if(coalesce(try_parse_json(r.variable_attr):customer_uuid::string,'') = '') raw_blank_uuid,  -- 853
       count_if(coalesce(try_parse_json(r.variable_attr):order_id::string,'') = '')      raw_blank_order, -- 853
       count_if(coalesce(r.customer_uuid,'') <> '')                                       raw_row_has_uuid -- 853
from blank b
left join prod_curated.porter_events.logged_in_customer_app_events r
  on r.event_id = b.event_id
 and to_timestamp_ntz(r.event_timestamp/1000)::date between '2026-10-18' and '2026-10-30';
