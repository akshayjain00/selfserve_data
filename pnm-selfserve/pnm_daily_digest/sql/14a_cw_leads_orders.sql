-- -> data/city_weekly/leads_orders.txt  (city|week MMDD|leads|orders|conv%; Network = all, incl. leads with no city). orders = segment; leads + conv = OVERALL
WITH g AS (SELECT geo_region_id, IFF(tier='Tier 1', city_name, 'Tier 2 (combined)') city FROM PROD_ELDORIA.CORE.DIM_GEO_REGIONS QUALIFY ROW_NUMBER() OVER (PARTITION BY geo_region_id ORDER BY updated_at DESC NULLS LAST)=1),
l AS (SELECT DATE_TRUNC('week',DATE(fpo.opp_created_ts)) w, fpo.opp_id id, g.city FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id=fpo.opp_id LEFT JOIN g ON g.geo_region_id=dpo.pickup_geo_region_id
 WHERE dpo.user_flag ILIKE 'normal' AND (dpo.shifting_type='intra_city' OR dpo.shifting_type IS NULL) AND DATE(fpo.opp_created_ts) BETWEEN '__CW_S__' AND '__CW_E__'),
o AS (SELECT DATE_TRUNC('week',DATE(o.o_created_ts)) w, o.order_id id, g.city, IFF(dpord.package_name ILIKE 'Nano%',1,0) nano FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS pc ON pc.customer_mobile=o.customer_mobile
 LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpord ON dpord.order_id=o.order_id LEFT JOIN g ON g.geo_region_id=dpord.pickup_geo_region_id
 WHERE dpord.user_flag ILIKE 'normal' AND dpord.shifting_type='intra_city' AND o.crn LIKE '%PNM%' AND DATE(o.o_created_ts) BETWEEN '__CW_S__' AND '__CW_E__'),
la AS (SELECT city, w, COUNT(DISTINCT id) n FROM l WHERE city IS NOT NULL GROUP BY 1,2 UNION ALL SELECT 'Network', w, COUNT(DISTINCT id) FROM l GROUP BY 2),
oa AS (SELECT city, w, COUNT(DISTINCT id) n, COUNT(DISTINCT IFF({{NANO:nano=1}},id,NULL)) ns FROM o WHERE city IS NOT NULL GROUP BY 1,2 UNION ALL SELECT 'Network', w, COUNT(DISTINCT id), COUNT(DISTINCT IFF({{NANO:nano=1}},id,NULL)) FROM o GROUP BY 2),
x AS (SELECT la.city, la.w, la.n leads, oa.ns orders, 100.0*oa.n/la.n conv FROM la JOIN oa ON la.city=oa.city AND la.w=oa.w)
SELECT LISTAGG(city||'|'||TO_CHAR(w,'MMDD')||'|'||leads||'|'||orders||'|'||ROUND(conv,2), ';') WITHIN GROUP (ORDER BY city, w) FROM x;
