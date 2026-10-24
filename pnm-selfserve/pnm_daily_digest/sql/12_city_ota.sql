-- -> data/city_ota.txt
WITH {{PERIODS}}, g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
orders AS (
 SELECT fpo.order_id, fpo.shifting_ts, DATE(fpo.o_completed_ts) d, dpo.sr_id, g.city, CASE WHEN dpo.package_name ILIKE 'Nano%' OR dpo.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN dpo.package_name ILIKE '1 RK%' OR dpo.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN dpo.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN dpo.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN dpo.package_name ILIKE '4 BHK%' OR dpo.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk
 FROM prod_eldoria.core.FACT_PNM_ORDERS fpo LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.order_id=fpo.order_id LEFT JOIN g ON g.geo_region_id=dpo.pickup_geo_region_id
 WHERE DATE(fpo.o_completed_ts) BETWEEN '__B_S__' AND '__R__' AND dpo.shifting_type='intra_city' AND dpo.order_status='completed' AND {{NANO:dpo.package_name ILIKE 'Nano%'}}
), pickup_loc AS (SELECT sr_id, location pickup_location FROM dev_eldoria.raw.pnm_application_sr_location_details WHERE location_type=0 QUALIFY ROW_NUMBER() OVER (PARTITION BY sr_id ORDER BY id DESC)=1
), ts AS (SELECT sa.order_id, sa.event_ts_ist event_ts, sa.location event_location FROM dev_eldoria.raw.pnm_application_supervisor_actions sa WHERE sa.action='ShiftingStarted' QUALIFY RANK() OVER (PARTITION BY sa.order_id ORDER BY sa.event_ts_ist DESC)=1
), c AS (SELECT o.*, CASE WHEN ts.event_ts IS NOT NULL AND DATEDIFF(SECONDS,o.shifting_ts,ts.event_ts)/60<30 AND ST_DISTANCE(pl.pickup_location,ts.event_location)/1000<2 THEN 1 ELSE 0 END ontime
 FROM orders o LEFT JOIN pickup_loc pl ON o.sr_id=pl.sr_id LEFT JOIN ts ON o.order_id=ts.order_id),
m AS (SELECT city, bhk, p.p, 100.0*COUNT(DISTINCT IFF(ontime=1,order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) v FROM c JOIN periods p ON c.d BETWEEN p.s AND p.e WHERE bhk<>'Unknown' AND city IS NOT NULL GROUP BY 1,2,3)
SELECT LISTAGG(city||'.'||bhk||'|'||ROUND(cur,2)||'|'||ROUND(base,2), ';') FROM (SELECT city, bhk, MAX(IFF(p='mtd_this',v,NULL)) cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),v,NULL)) base FROM m GROUP BY 1,2);
