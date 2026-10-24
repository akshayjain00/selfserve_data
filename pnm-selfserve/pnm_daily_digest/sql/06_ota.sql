-- -> data/ota.txt  (Card #37409 definition; o_completed_ts basis)
WITH {{PERIODS}}, orders AS (
 SELECT fpo.order_id, fpo.shifting_ts, DATE(fpo.o_completed_ts) d, dpo.package_name, dpo.order_status, dpo.sr_id
 FROM prod_eldoria.core.FACT_PNM_ORDERS fpo LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.order_id=fpo.order_id
 WHERE DATE(fpo.o_completed_ts) BETWEEN '__B_S__' AND '__R__' AND dpo.shifting_type='intra_city'
), pickup_loc AS (SELECT sr_id, location pickup_location FROM dev_eldoria.raw.pnm_application_sr_location_details WHERE location_type=0 QUALIFY ROW_NUMBER() OVER (PARTITION BY sr_id ORDER BY id DESC)=1
), ts AS (SELECT sa.order_id, sa.event_ts_ist event_ts, sa.location event_location FROM dev_eldoria.raw.pnm_application_supervisor_actions sa WHERE sa.action='ShiftingStarted' QUALIFY RANK() OVER (PARTITION BY sa.order_id ORDER BY sa.event_ts_ist DESC)=1
), c AS (
 SELECT o.*, IFF(o.order_status='completed' AND {{NANO:o.package_name ILIKE 'Nano%'}},1,0) elig,
  CASE WHEN o.order_status='completed' AND {{NANO:o.package_name ILIKE 'Nano%'}} AND ts.event_ts IS NOT NULL AND DATEDIFF(SECONDS,o.shifting_ts,ts.event_ts)/60<30 AND ST_DISTANCE(pl.pickup_location,ts.event_location)/1000<2 THEN 1 ELSE 0 END ontime,
  IFF(ts.event_ts IS NOT NULL AND DATEDIFF(SECONDS,o.shifting_ts,ts.event_ts)/60.0>=60,1,0) d60
 FROM orders o LEFT JOIN pickup_loc pl ON o.sr_id=pl.sr_id LEFT JOIN ts ON o.order_id=ts.order_id
), t AS (SELECT p.p, (100.0*COUNT(DISTINCT IFF(ontime=1,order_id,NULL))/NULLIF(COUNT(DISTINCT IFF(elig=1,order_id,NULL)),0))::FLOAT ota,
  (100.0*COUNT(DISTINCT IFF(elig=1 AND d60=1,order_id,NULL))/NULLIF(COUNT(DISTINCT IFF(elig=1,order_id,NULL)),0))::FLOAT delay60
  FROM c JOIN periods p ON c.d BETWEEN p.s AND p.e GROUP BY 1),
u AS (SELECT * FROM t UNPIVOT (val FOR metric IN (ota, delay60)))
{{FINAL}}
