-- -> data/city_weekly/aov_surge.txt  (city|week|aov|surge%)
WITH g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
f AS (SELECT f.*, g.city FROM PROD_ELDORIA.MART.PNM_FARE_MOVEMENT f LEFT JOIN g ON g.geo_region_id=f.pickup_geo_region_id WHERE f.service_type_bucket='intracity'),
f2 AS (SELECT *, city c FROM f WHERE city IS NOT NULL UNION ALL SELECT *, 'Network' FROM f),
a AS (SELECT c, DATE_TRUNC('week',DATE(order_updated_at_ist)) w, SUM(total_order_fare)/NULLIF(COUNT(DISTINCT order_id),0) aov FROM f2
 WHERE order_status='completed' AND {{NANO:package_name ILIKE 'Nano%'}} AND is_test_user=0 AND DATE(order_updated_at_ist) BETWEEN '__CW_S__' AND '__CW_E__' GROUP BY 1,2),
s AS (SELECT c, DATE_TRUNC('week',order_created_date) w, 100.0*COUNT(DISTINCT IFF(booking_surge_multiplier<>1 AND booking_surge_multiplier IS NOT NULL,order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) surge FROM f2
 WHERE {{NANO:is_nano_order=1}} AND order_created_date BETWEEN '__CW_S__' AND '__CW_E__' GROUP BY 1,2)
SELECT LISTAGG(a.c||'|'||TO_CHAR(a.w,'MMDD')||'|'||ROUND(aov,0)||'|'||ROUND(surge,2), ';') WITHIN GROUP (ORDER BY a.c, a.w) FROM a JOIN s ON a.c=s.c AND a.w=s.w;
