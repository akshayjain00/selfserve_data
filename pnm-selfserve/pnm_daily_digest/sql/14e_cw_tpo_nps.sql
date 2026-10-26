-- -> data/city_weekly/tpo_nps.txt  (city|week|tpo|nps|detr%)
WITH g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
o AS (SELECT s.crn, DATE_TRUNC('week',DATE(s.completed_ts_ist)) w, g.city FROM PROD_ELDORIA.MART.PNM_SUPPORT s LEFT JOIN g ON g.geo_region_id=s.pickup_geo_region_id
  WHERE {{NANO:s.package_name ILIKE '%Nano%'}} AND s.shifting_type='intra_city' AND DATE(s.completed_ts_ist) BETWEEN '__CW_S__' AND '__CW_E__'),
o2 AS (SELECT *, city c FROM o WHERE city IS NOT NULL UNION ALL SELECT *, 'Network' FROM o),
k AS (SELECT DISTINCT ticket_number, crn FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS WHERE COALESCE(raised_by,'')!='Detractor' AND DATE(created_at + interval '5 hours, 30 minutes') BETWEEN '__CW_S__' AND '__R__'),
t AS (SELECT o2.c, o2.w, COUNT(DISTINCT k.ticket_number)/NULLIF(COUNT(DISTINCT o2.crn),0) tpo FROM o2 LEFT JOIN k ON k.crn=o2.crn GROUP BY 1,2),
e AS (SELECT x.order_id, x.classification, DATE_TRUNC('week',x.order_completed_ts_ist::date) w, g.city FROM PROD_ELDORIA.MART.PNM_EXPERIENCE x LEFT JOIN g ON g.geo_region_id=x.pickup_geo_region_id
  WHERE {{NANO:x.package_name ILIKE 'Nano%'}} AND x.shifting_type='intra_city' AND x.order_status='completed' AND x.order_completed_ts_ist::date BETWEEN '__CW_S__' AND '__CW_E__'),
e2 AS (SELECT *, city c FROM e WHERE city IS NOT NULL UNION ALL SELECT *, 'Network' FROM e),
n AS (SELECT c, w, 100.0*(COUNT(DISTINCT IFF(classification='Promoter',order_id,NULL))-COUNT(DISTINCT IFF(classification='Detractor',order_id,NULL)))/NULLIF(COUNT(DISTINCT IFF(classification IS NOT NULL,order_id,NULL)),0) nps,
  100.0*COUNT(DISTINCT IFF(classification='Detractor',order_id,NULL))/NULLIF(COUNT(DISTINCT order_id),0) detr FROM e2 GROUP BY 1,2)
SELECT LISTAGG(t.c||'|'||TO_CHAR(t.w,'MMDD')||'|'||ROUND(tpo,3)||'|'||ROUND(nps,2)||'|'||ROUND(detr,2), ';') WITHIN GROUP (ORDER BY t.c, t.w) FROM t JOIN n ON t.c=n.c AND t.w=n.w;
