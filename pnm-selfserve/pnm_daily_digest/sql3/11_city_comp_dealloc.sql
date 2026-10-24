-- 3-segment version of sql/11_city_comp_dealloc.sql -> save_result.py 11_city_comp_dealloc.sql
WITH {{PERIODS}}, per7 AS (SELECT * FROM periods WHERE p IN ('mtd_this','m1','m2','m3','m4','m5','m6')), segs AS (SELECT 'all' seg UNION ALL SELECT 'nn' UNION ALL SELECT 'nano'), g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
a AS (SELECT x.order_id, x.order_status, x.is_deallocated_post_accept, IFF(x.is_nano_order=1,1,0) nano, g.city, TO_DATE(x.shifting_ts_ist) d, CASE WHEN x.package_name ILIKE 'Nano%' OR x.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN x.package_name ILIKE '1 RK%' OR x.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN x.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN x.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN x.package_name ILIKE '4 BHK%' OR x.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk
  FROM PROD_ELDORIA.MART.PNM_ALLOCATION x LEFT JOIN g ON g.geo_region_id=x.pickup_geo_region_id
  WHERE x.shifting_type='intra_city' AND x.is_test_user=0 AND TO_DATE(x.shifting_ts_ist) BETWEEN '__B_S__' AND '__R__'),
m AS (SELECT seg, city, bhk, p.p,
  100.0*COUNT(DISTINCT IFF(order_status='completed',order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) c,
  100.0*COUNT(DISTINCT IFF(is_deallocated_post_accept=1,order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) de
  FROM a JOIN segs ON CASE seg WHEN 'all' THEN TRUE WHEN 'nn' THEN nano=0 ELSE nano=1 END JOIN per7 p ON a.d BETWEEN p.s AND p.e WHERE city IS NOT NULL AND bhk<>'Unknown' GROUP BY 1,2,3,4),
c AS (SELECT seg, city, bhk, MAX(IFF(p='mtd_this',c,NULL)) comp_cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),c,NULL)) comp_base,
  MAX(IFF(p='mtd_this',de,NULL)) de_cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),de,NULL)) de_base FROM m GROUP BY 1,2,3),
x AS (SELECT seg, city||'.'||bhk||'|'||NVL(TO_VARCHAR(ROUND(comp_cur,2)),'')||'|'||NVL(TO_VARCHAR(ROUND(comp_base,2)),'')||'|'||NVL(TO_VARCHAR(ROUND(de_cur,2)),'')||'|'||NVL(TO_VARCHAR(ROUND(de_base,2)),'') rec FROM c)
SELECT (SELECT LISTAGG(rec,';') FROM x WHERE seg='all'), (SELECT LISTAGG(rec,';') FROM x WHERE seg='nn'), (SELECT LISTAGG(rec,';') FROM x WHERE seg='nano')
