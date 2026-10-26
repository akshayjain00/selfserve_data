-- -> data/city_orders.txt : 'CITY_LO=' + col city_lo + ';(No city yet)|<nocity>|0' (never shown on page; feeds the note) ; 'ORDERS=' + col orders_grid
-- ORDERS grid follows the Nano segment; CITY_LO (leads + orders by city, conversion context) stays OVERALL. Orders base = mean of the 6 previous months' MTD-equivalent (day 1..R.day) counts
WITH {{PERIODS}}, g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
o AS (
 SELECT DATE(o.o_created_ts) d, o.order_id id, g.city, CASE WHEN dpord.package_name ILIKE 'Nano%' OR dpord.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN dpord.package_name ILIKE '1 RK%' OR dpord.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN dpord.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN dpord.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN dpord.package_name ILIKE '4 BHK%' OR dpord.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk, IFF(dpord.package_name ILIKE 'Nano%',1,0) nano
 FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS pc ON pc.customer_mobile=o.customer_mobile
 LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpord ON dpord.order_id=o.order_id LEFT JOIN g ON g.geo_region_id=dpord.pickup_geo_region_id
 WHERE dpord.user_flag ILIKE 'normal' AND dpord.shifting_type='intra_city' AND o.crn LIKE '%PNM%' AND DATE(o.o_created_ts) BETWEEN '__B_S__' AND '__R__'
), l AS (
 SELECT fpo.opp_id id, g.city FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id=fpo.opp_id LEFT JOIN g ON g.geo_region_id=dpo.pickup_geo_region_id
 WHERE dpo.user_flag ILIKE 'normal' AND (dpo.shifting_type='intra_city' OR dpo.shifting_type IS NULL) AND DATE(fpo.opp_created_ts) BETWEEN '__MTD_S__' AND '__R__'
), oc AS (SELECT city, bhk, p.p, COUNT(DISTINCT id) v FROM o JOIN periods p ON o.d BETWEEN p.s AND p.e WHERE city IS NOT NULL AND bhk<>'Unknown' AND {{NANO:nano=1}} AND p.p IN ('mtd_this','m1','m2','m3','m4','m5','m6') GROUP BY 1,2,3),
og AS (SELECT city, bhk, MAX(IFF(p='mtd_this',v,NULL)) cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),v,NULL)) base FROM oc GROUP BY 1,2)
SELECT
 (SELECT LISTAGG(city||'|'||nl||'|'||NVL(no,0), ';') FROM (SELECT a.city, a.nl, b.no FROM (SELECT city, COUNT(DISTINCT id) nl FROM l WHERE city IS NOT NULL GROUP BY 1) a LEFT JOIN (SELECT city, COUNT(DISTINCT id) no FROM o WHERE d>='__MTD_S__' GROUP BY 1) b ON a.city=b.city)) city_lo,
 (SELECT COUNT(DISTINCT id) FROM l WHERE city IS NULL) nocity,
 (SELECT LISTAGG(city||'.'||bhk||'|'||NVL(cur,0)||'|'||ROUND(base,1), ';') FROM og) orders_grid;
