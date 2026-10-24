-- -> data/leads.txt  Leads + Conversion = OVERALL (Nano filter not applied, user 12 Oct); orders + channel shares follow the segment.  (order channel: orders.sr_id -> RAW.PNM_APPLICATION_OPPORTUNITIES.sr_id -> DIM_PNM_OPPORTUNITY; unmatched -> mob)
WITH {{PERIODS}}, l AS (
 SELECT DATE(fpo.opp_created_ts) d, fpo.opp_id id, CASE WHEN dpo.source_details='Desktop Website' THEN 'desk' WHEN dpo.source_details='Mobile Website' THEN 'mob' WHEN dpo.source IN (1,2,3) THEN 'app' WHEN dpo.source=4 THEN 'oth' ELSE 'mob' END ch
 FROM PROD_ELDORIA.CORE.FACT_PNM_OPPORTUNITY fpo LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id=fpo.opp_id
 WHERE dpo.user_flag ILIKE 'normal' AND (dpo.shifting_type='intra_city' OR dpo.shifting_type IS NULL) AND DATE(fpo.opp_created_ts) BETWEEN '__B_S__' AND '__R__'
), opp AS (SELECT op.sr_id, CASE WHEN dpo.source_details='Desktop Website' THEN 'desk' WHEN dpo.source_details='Mobile Website' THEN 'mob' WHEN dpo.source IN (1,2,3) THEN 'app' WHEN dpo.source=4 THEN 'oth' ELSE 'mob' END ch
  FROM PROD_ELDORIA.RAW.PNM_APPLICATION_OPPORTUNITIES op JOIN PROD_ELDORIA.CORE.DIM_PNM_OPPORTUNITY dpo ON dpo.opp_id=op.id WHERE op.sr_id IS NOT NULL QUALIFY ROW_NUMBER() OVER (PARTITION BY op.sr_id ORDER BY op.created_at_ist DESC)=1
), o AS (
 SELECT DATE(o.o_created_ts) d, o.order_id id, COALESCE(opp.ch,'mob') ch, IFF(dpord.package_name ILIKE 'Nano%',1,0) nano
 FROM PROD_ELDORIA.CORE.FACT_PNM_ORDERS o INNER JOIN PROD_ELDORIA.MART.PNM_CUSTOMERS pc ON pc.customer_mobile=o.customer_mobile
 LEFT JOIN PROD_ELDORIA.CORE.DIM_PNM_ORDERS dpord ON dpord.order_id=o.order_id LEFT JOIN opp ON opp.sr_id=o.sr_id
 WHERE dpord.user_flag ILIKE 'normal' AND dpord.shifting_type='intra_city' AND o.crn LIKE '%PNM%' AND DATE(o.o_created_ts) BETWEEN '__B_S__' AND '__R__'
), la AS (SELECT p.p, COUNT(DISTINCT id) l_all, COUNT(DISTINCT IFF(ch='app',id,NULL)) l_app, COUNT(DISTINCT IFF(ch='mob',id,NULL)) l_mob, COUNT(DISTINCT IFF(ch='desk',id,NULL)) l_desk, COUNT(DISTINCT IFF(ch='oth',id,NULL)) l_oth FROM l JOIN periods p ON l.d BETWEEN p.s AND p.e GROUP BY 1
), oa AS (SELECT p.p, COUNT(DISTINCT id) t_all, COUNT(DISTINCT IFF(ch='app',id,NULL)) t_app, COUNT(DISTINCT IFF(ch='mob',id,NULL)) t_mob, COUNT(DISTINCT IFF(ch='desk',id,NULL)) t_desk,
  COUNT(DISTINCT IFF({{NANO:nano=1}},id,NULL)) o_all, COUNT(DISTINCT IFF({{NANO:nano=1}} AND ch='app',id,NULL)) o_app, COUNT(DISTINCT IFF({{NANO:nano=1}} AND ch='mob',id,NULL)) o_mob,
  COUNT(DISTINCT IFF({{NANO:nano=1}} AND ch='desk',id,NULL)) o_desk, COUNT(DISTINCT IFF({{NANO:nano=1}} AND ch='oth',id,NULL)) o_oth FROM o JOIN periods p ON o.d BETWEEN p.s AND p.e GROUP BY 1
), t AS (SELECT la.p, l_all::FLOAT l_all, l_app::FLOAT l_app, l_mob::FLOAT l_mob, l_desk::FLOAT l_desk, l_oth::FLOAT l_oth, o_all::FLOAT o_all,
  (100.0*t_all/l_all)::FLOAT c_all, (100.0*t_app/l_app)::FLOAT c_app, (100.0*t_desk/l_desk)::FLOAT c_desk, (100.0*t_mob/l_mob)::FLOAT c_mob,
  (100.0*o_app/NULLIF(o_all,0))::FLOAT s_app, (100.0*(o_mob+o_desk)/NULLIF(o_all,0))::FLOAT s_web, (100.0*o_oth/NULLIF(o_all,0))::FLOAT s_lms
  FROM la JOIN oa ON la.p=oa.p
), u AS (SELECT * FROM t UNPIVOT (val FOR metric IN (l_all,l_app,l_mob,l_desk,l_oth,o_all,c_all,c_app,c_desk,c_mob,s_app,s_web,s_lms)))
{{FINAL}}
