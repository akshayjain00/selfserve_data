-- -> data/trip_edits.txt  (Trip: shifting_ts_ist basis; Edits/Add-ons: order_created_ts_ist basis; completed, Nano excluded)
WITH {{PERIODS}}, e AS (SELECT * FROM PROD_ELDORIA.MART.PNM_EXPERIENCE WHERE shifting_type='intra_city' AND order_status='completed' AND {{NANO:package_name ILIKE 'Nano%'}}),
tr AS (SELECT p.p,
 PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF(minute,vendor_owner_accepted_ts_ist,supervisor_accepted_ts_ist))::FLOAT s1,
 PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF(minute,supervisor_accepted_ts_ist,trip_started_ts_ist))::FLOAT s2,
 PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF(minute,trip_started_ts_ist,shifting_started_ts_ist))::FLOAT s3,
 PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF(minute,shifting_started_ts_ist,pickup_completed_ts_ist))::FLOAT s4,
 PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF(minute,pickup_completed_ts_ist,order_completed_ts_ist))::FLOAT s5,
 PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY DATEDIFF(minute,shifting_started_ts_ist,order_completed_ts_ist))::FLOAT s6
 FROM e JOIN periods p ON e.shifting_ts_ist::date BETWEEN p.s AND p.e GROUP BY 1),
ed AS (SELECT p.p,
 (100.0*COUNT(DISTINCT IFF(is_modification_done='Yes',order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT edited,
 (100.0*COUNT(DISTINCT IFF(has_support_edit=1,order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT sup_edit,
 (100.0*SUM(edits_after_shifting)/NULLIF(SUM(no_of_successful_edits),0))::FLOAT eas,
 (100.0*COUNT(DISTINCT IFF(has_location_edit=1,order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT loc_edit,
 (100.0*COUNT(DISTINCT IFF(add_ons IS NOT NULL AND add_ons!='',order_id,NULL))/COUNT(DISTINCT order_id))::FLOAT addon
 FROM e JOIN periods p ON e.order_created_ts_ist::date BETWEEN p.s AND p.e GROUP BY 1),
t AS (SELECT tr.*, edited, sup_edit, eas, loc_edit, addon FROM tr JOIN ed ON tr.p=ed.p),
u AS (SELECT * FROM t UNPIVOT (val FOR metric IN (s1,s2,s3,s4,s5,s6,edited,sup_edit,eas,loc_edit,addon)))
{{FINAL}}
