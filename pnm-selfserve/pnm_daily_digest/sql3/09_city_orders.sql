-- 3-segment version of sql/09_city_orders.sql -> save_result.py 09_city_orders.sql (3 columns per segment; CITY_LO + nocity are overall)
WITH {{PERIODS}}, segs AS (SELECT 'all' seg UNION ALL SELECT 'nn' UNION ALL SELECT 'nano'), g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
o AS (
 SELECT DATE(o.o_created_ts) d, o.order_id id, g.city, CASE WHEN dpord.package_name ILIKE 'Nano%' OR dpord.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN dpord.package_name ILIKE '1 RK%' OR dpord.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN dpord.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN dpord.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN dpord.package_name ILIKE '4 BHK%' OR dpord.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk, IFF(dpord.package_name ILIKE 'Nano%',1,0) nano
 FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS pc ON pc.customer_mobile=o.customer_mobile
 LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpord ON dpord.order_id=o.order_id LEFT JOIN g ON g.geo_region_id=dpord.pickup_geo_region_id
 WHERE dpord.user_flag ILIKE 'normal' AND dpord.shifting_type='intra_city' AND o.crn LIKE '%PNM%' AND DATE(o.o_created_ts) BETWEEN '__B_S__' AND '__R__'
), l AS (
 SELECT fpo.opp_id id, g.city FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id=fpo.opp_id LEFT JOIN g ON g.geo_region_id=dpo.pickup_geo_region_id
 WHERE dpo.user_flag ILIKE 'normal' AND (dpo.shifting_type='intra_city' OR dpo.shifting_type IS NULL) AND DATE(fpo.opp_created_ts) BETWEEN '__MTD_S__' AND '__R__'
), oc AS (SELECT seg, city, bhk, p.p, COUNT(DISTINCT id) v FROM o JOIN segs ON CASE seg WHEN 'all' THEN TRUE WHEN 'nn' THEN nano=0 ELSE nano=1 END JOIN periods p ON o.d BETWEEN p.s AND p.e WHERE city IS NOT NULL AND bhk<>'Unknown' AND p.p IN ('mtd_this','m1','m2','m3','m4','m5','m6') GROUP BY 1,2,3,4),
og AS (SELECT seg, city, bhk, MAX(IFF(p='mtd_this',v,NULL)) cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),v,NULL)) base FROM oc GROUP BY 1,2,3),
lo AS (SELECT LISTAGG(city||'|'||nl||'|'||NVL(no,0), ';') x FROM (SELECT a.city, a.nl, b.no FROM (SELECT city, COUNT(DISTINCT id) nl FROM l WHERE city IS NOT NULL GROUP BY 1) a LEFT JOIN (SELECT city, COUNT(DISTINCT id) no FROM o WHERE d>='__MTD_S__' GROUP BY 1) b ON a.city=b.city)),
nc AS (SELECT COUNT(DISTINCT id) x FROM l WHERE city IS NULL)
SELECT (SELECT x FROM lo), (SELECT x FROM nc), (SELECT LISTAGG(city||'.'||bhk||'|'||NVL(cur,0)||'|'||ROUND(base,1), ';') FROM og WHERE seg='all'),
 (SELECT x FROM lo), (SELECT x FROM nc), (SELECT LISTAGG(city||'.'||bhk||'|'||NVL(cur,0)||'|'||ROUND(base,1), ';') FROM og WHERE seg='nn'),
 (SELECT x FROM lo), (SELECT x FROM nc), (SELECT LISTAGG(city||'.'||bhk||'|'||NVL(cur,0)||'|'||ROUND(base,1), ';') FROM og WHERE seg='nano')
