-- -> data/pricing.txt  (AOV: order_updated basis; surge: order_created_date; fare increase: shifting_started basis. Nano per segment toggle: {{NANO:...}})
WITH {{PERIODS}}, f AS (SELECT *, IFF({{NANO:package_name ILIKE 'Nano%'}} AND is_test_user=0,1,0) nn FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT WHERE service_type_bucket='intracity'),
a AS (SELECT p.p, (SUM(IFF(order_status='completed' AND nn=1,total_order_fare,NULL))/NULLIF(COUNT(DISTINCT IFF(order_status='completed' AND nn=1,order_id,NULL)),0))::FLOAT aov FROM f JOIN periods p ON DATE(f.order_updated_at_ist) BETWEEN p.s AND p.e GROUP BY 1),
s AS (SELECT p.p, (100.0*COUNT(DISTINCT IFF(booking_surge_multiplier<>1 AND booking_surge_multiplier IS NOT NULL,order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT surge,
  (100.0*COUNT(DISTINCT IFF(booking_surge_multiplier>1,order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT pos, (100.0*COUNT(DISTINCT IFF(booking_surge_multiplier<1,order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT neg
  FROM f JOIN periods p ON f.order_created_date BETWEEN p.s AND p.e WHERE {{NANO:is_nano_order=1}} GROUP BY 1),
fi AS (SELECT p.p, (100.0*COUNT(DISTINCT IFF(fare_delta>0 AND nn=1,order_id,NULL))/NULLIF(COUNT(DISTINCT IFF(shifting_started_ts_ist IS NOT NULL AND nn=1,order_id,NULL)),0))::FLOAT fi_nn,
  MEDIAN(IFF(fare_delta>0 AND nn=1,fare_delta,NULL))::FLOAT med_nn
  FROM f JOIN periods p ON DATE(f.shifting_started_ts_ist) BETWEEN p.s AND p.e GROUP BY 1),
t AS (SELECT a.p, aov, surge, pos, neg, fi_nn, med_nn FROM a JOIN s ON a.p=s.p JOIN fi ON a.p=fi.p),
u AS (SELECT * FROM t UNPIVOT (val FOR metric IN (aov, surge, pos, neg, fi_nn, med_nn)))
{{FINAL}}
