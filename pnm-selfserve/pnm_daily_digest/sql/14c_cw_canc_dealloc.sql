-- -> data/city_weekly/canc_dealloc.txt  (city|week|cancel%|dealloc%)
WITH g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
a AS (SELECT x.order_id, x.cancellation_type, x.is_deallocated_post_accept, DATE_TRUNC('week',TO_DATE(x.shifting_ts_ist)) w, g.city FROM PROD_ELDORIA.MART.PNM_ALLOCATION x LEFT JOIN g ON g.geo_region_id=x.pickup_geo_region_id
 WHERE x.shifting_type='intra_city' AND {{NANO:x.is_nano_order=1}} AND x.is_test_user=0 AND TO_DATE(x.shifting_ts_ist) BETWEEN '__CW_S__' AND '__CW_E__'),
a2 AS (SELECT *, city c FROM a WHERE city IS NOT NULL UNION ALL SELECT *, 'Network' FROM a),
r AS (SELECT c, w, 100.0*COUNT(DISTINCT IFF(cancellation_type IN ('CAC','PAC','PoAC'),order_id,NULL))/COUNT(DISTINCT order_id) canc,
  100.0*COUNT(DISTINCT IFF(is_deallocated_post_accept=1,order_id,NULL))/COUNT(DISTINCT order_id) deal FROM a2 GROUP BY 1,2)
SELECT LISTAGG(c||'|'||TO_CHAR(w,'MMDD')||'|'||ROUND(canc,2)||'|'||ROUND(deal,2), ';') WITHIN GROUP (ORDER BY c, w) FROM r;
