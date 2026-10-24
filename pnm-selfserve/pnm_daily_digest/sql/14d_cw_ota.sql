-- -> data/city_weekly/ota.txt  (city|week|ota%) Card #37409
WITH g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
orders AS (SELECT fpo.order_id, fpo.shifting_ts, DATE_TRUNC('week',DATE(fpo.o_completed_ts)) w, dpo.sr_id, g.city
 FROM prod_eldoria.core.FACT_PNM_ORDERS fpo LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.order_id=fpo.order_id LEFT JOIN g ON g.geo_region_id=dpo.pickup_geo_region_id
 WHERE DATE(fpo.o_completed_ts) BETWEEN '__CW_S__' AND '__CW_E__' AND dpo.shifting_type='intra_city' AND dpo.order_status='completed' AND {{NANO:dpo.package_name ILIKE 'Nano%'}}
), pickup_loc AS (SELECT sr_id, location pickup_location FROM dev_eldoria.raw.pnm_application_sr_location_details WHERE location_type=0 QUALIFY ROW_NUMBER() OVER (PARTITION BY sr_id ORDER BY id DESC)=1
), ts AS (SELECT sa.order_id, sa.event_ts_ist event_ts, sa.location event_location FROM dev_eldoria.raw.pnm_application_supervisor_actions sa WHERE sa.action='ShiftingStarted' QUALIFY RANK() OVER (PARTITION BY sa.order_id ORDER BY sa.event_ts_ist DESC)=1
), c AS (SELECT o.*, CASE WHEN ts.event_ts IS NOT NULL AND DATEDIFF(SECONDS,o.shifting_ts,ts.event_ts)/60<30 AND ST_DISTANCE(pl.pickup_location,ts.event_location)/1000<2 THEN 1 ELSE 0 END ontime
 FROM orders o LEFT JOIN pickup_loc pl ON o.sr_id=pl.sr_id LEFT JOIN ts ON o.order_id=ts.order_id),
c2 AS (SELECT *, city cc FROM c WHERE city IS NOT NULL UNION ALL SELECT *, 'Network' FROM c),
r AS (SELECT cc, w, 100.0*COUNT(DISTINCT IFF(ontime=1,order_id,NULL))/COUNT(DISTINCT order_id) ota FROM c2 GROUP BY 1,2)
SELECT LISTAGG(cc||'|'||TO_CHAR(w,'MMDD')||'|'||ROUND(ota,2), ';') WITHIN GROUP (ORDER BY cc, w) FROM r;
