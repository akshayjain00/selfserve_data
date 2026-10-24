-- -> data/city_tpo_nps.txt : 'TPO=' + col 1 ; 'NPS=' + col 2 (nps_cur|nps_base|detr_cur|detr_base|rated_cur)
WITH {{PERIODS}}, g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
o AS (SELECT s.crn, DATE(s.completed_ts_ist) d, g.city, CASE WHEN s.package_name ILIKE 'Nano%' OR s.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN s.package_name ILIKE '1 RK%' OR s.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN s.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN s.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN s.package_name ILIKE '4 BHK%' OR s.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk
  FROM PROD_ELDORIA.MART.PNM_SUPPORT s LEFT JOIN g ON g.geo_region_id=s.pickup_geo_region_id WHERE {{NANO:s.package_name ILIKE '%Nano%'}} AND s.shifting_type='intra_city' AND DATE(s.completed_ts_ist) BETWEEN '__B_S__' AND '__R__'),
k AS (SELECT DISTINCT ticket_number, crn FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS WHERE COALESCE(raised_by,'')!='Detractor' AND DATE(created_at + interval '5 hours, 30 minutes') BETWEEN '__B_S__' AND '__R__'),
tm AS (SELECT o.city, o.bhk, p.p, COUNT(DISTINCT k.ticket_number)/NULLIF(COUNT(DISTINCT o.crn),0) v FROM o JOIN periods p ON o.d BETWEEN p.s AND p.e LEFT JOIN k ON k.crn=o.crn WHERE o.bhk<>'Unknown' AND o.city IS NOT NULL GROUP BY 1,2,3),
e AS (SELECT x.order_id, x.classification, x.order_completed_ts_ist::date d, g.city, CASE WHEN x.package_name ILIKE 'Nano%' OR x.package_name ILIKE 'Micro%' THEN 'Nano/Micro' WHEN x.package_name ILIKE '1 RK%' OR x.package_name ILIKE '1 BHK%' THEN '1BHK' WHEN x.package_name ILIKE '2 BHK%' THEN '2BHK' WHEN x.package_name ILIKE '3 BHK%' THEN '3BHK' WHEN x.package_name ILIKE '4 BHK%' OR x.package_name ILIKE '5 BHK%' THEN '4+BHK' ELSE 'Unknown' END bhk
  FROM PROD_ELDORIA.MART.PNM_EXPERIENCE x LEFT JOIN g ON g.geo_region_id=x.pickup_geo_region_id WHERE {{NANO:x.package_name ILIKE 'Nano%'}} AND x.shifting_type='intra_city' AND x.order_status='completed' AND x.order_completed_ts_ist::date BETWEEN '__B_S__' AND '__R__'),
nm AS (SELECT city, bhk, p.p,
  100.0*(COUNT(DISTINCT IFF(classification='Promoter',order_id,NULL))-COUNT(DISTINCT IFF(classification='Detractor',order_id,NULL)))/NULLIF(COUNT(DISTINCT IFF(classification IS NOT NULL,order_id,NULL)),0) n,
  100.0*COUNT(DISTINCT IFF(classification='Detractor',order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) dt,
  COUNT(DISTINCT IFF(classification IS NOT NULL,order_id,NULL)) rated
  FROM e JOIN periods p ON e.d BETWEEN p.s AND p.e WHERE bhk<>'Unknown' AND city IS NOT NULL GROUP BY 1,2,3),
nps AS (SELECT city, bhk, MAX(IFF(p='mtd_this',n,NULL)) n_cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),n,NULL)) n_base,
  MAX(IFF(p='mtd_this',dt,NULL)) d_cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),dt,NULL)) d_base, MAX(IFF(p='mtd_this',rated,NULL)) rated_cur FROM nm GROUP BY 1,2)
SELECT (SELECT LISTAGG(city||'.'||bhk||'|'||ROUND(cur,3)||'|'||ROUND(base,3), ';') FROM (SELECT city, bhk, MAX(IFF(p='mtd_this',v,NULL)) cur, AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),v,NULL)) base FROM tm GROUP BY 1,2)) tpo,
 (SELECT LISTAGG(city||'.'||bhk||'|'||ROUND(n_cur,2)||'|'||ROUND(n_base,2)||'|'||ROUND(d_cur,2)||'|'||ROUND(d_base,2)||'|'||NVL(rated_cur,0), ';') FROM nps) nps;
