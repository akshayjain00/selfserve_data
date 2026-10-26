-- -> data/city_comp_dealloc.txt (comp_cur|comp_base|dealloc_cur|dealloc_base)
WITH {{PERIODS}}, g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
a AS (SELECT x.*, g.city, TO_DATE(x.shifting_ts_ist) d, CASE WHEN x.package_name ILIKE 'Nano%' OR x.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN x.package_name ILIKE '1 RK%' OR x.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN x.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN x.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN x.package_name ILIKE '4 BHK%' OR x.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk
  FROM PROD_ELDORIA.MART.PNM_ALLOCATION x LEFT JOIN g ON g.geo_region_id=x.pickup_geo_region_id
  WHERE x.shifting_type='intra_city' AND {{NANO:x.is_nano_order=1}} AND x.is_test_user=0 AND TO_DATE(x.shifting_ts_ist) BETWEEN '__B_S__' AND '__R__'),
m AS (SELECT city, bhk, p.p,
  100.0*COUNT(DISTINCT IFF(order_status='completed',order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) c,
  100.0*COUNT(DISTINCT IFF(is_deallocated_post_accept=1,order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) de
  FROM a JOIN periods p ON a.d BETWEEN p.s AND p.e WHERE city IS NOT NULL AND bhk<>'Unknown' GROUP BY 1,2,3),
c AS (SELECT city, bhk, MAX(IFF(p='mtd_this',c,NULL)) comp_cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),c,NULL)) comp_base,
  MAX(IFF(p='mtd_this',de,NULL)) de_cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),de,NULL)) de_base FROM m GROUP BY 1,2)
SELECT LISTAGG(city||'.'||bhk||'|'||ROUND(comp_cur,2)||'|'||ROUND(comp_base,2)||'|'||ROUND(de_cur,2)||'|'||ROUND(de_base,2), ';') FROM c;
