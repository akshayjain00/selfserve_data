-- 3-segment version of sql/08_escalations.sql -> save_result.py 08_escalations.sql
WITH {{PERIODS}}, segs AS (SELECT 'all' seg UNION ALL SELECT 'nn' UNION ALL SELECT 'nano'),
sm_data AS (
    SELECT sm."Order_ID" AS crn, sm."Key_reason" AS Key_reason, sm."Received_Date" AS Received_Date FROM PROD_CURATED.GSHEET_SYNC.PNM_SOCIAL_MEDIA_ESCALATIONS_DETAILS sm
    WHERE "Received_Date" != '#N/A' AND (sm."Order_ID" ILIKE '%NM%' OR sm."Order_ID" ILIKE '%PM%')
), ceo_data AS (
    SELECT sm."Order_ID" AS crn, sm."Key_reason" AS Key_reason, sm."Received_Date" AS Received_Date FROM PROD_CURATED.GSHEET_SYNC.PNM_CEO_ESCALATIONS_DETAILS sm
    WHERE "Received_Date" != '#N/A' AND (sm."Order_ID" ILIKE '%NM%' OR sm."Order_ID" ILIKE '%PM%')
), sm_merged AS (
    SELECT CASE WHEN (crn ILIKE '%NM%' OR crn ILIKE '%PM%') THEN 'PNM' || REGEXP_REPLACE(crn, '[^0-9]', '') ELSE crn END AS crn, Key_reason,
        COALESCE(TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'DD/MM/YYYY'), TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'DD-MON-YY'), TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'MM/DD/YYYY')) AS ticket_ts FROM sm_data
    UNION ALL
    SELECT CASE WHEN (crn ILIKE '%NM%' OR crn ILIKE '%PM%') THEN 'PNM' || REGEXP_REPLACE(crn, '[^0-9]', '') ELSE crn END AS crn, Key_reason,
        COALESCE(TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'DD-MON-YY'), TRY_TO_DATE(NULLIF(Received_Date,'#N/A'),'MM/DD/YYYY')) AS ticket_ts FROM ceo_data
), esc0 AS (
 SELECT DISTINCT trim(sm.crn)||' - '||trim(sm.Key_reason) AS uuid, sm.ticket_ts d, IFF(dpo.package_name ILIKE '%Nano%',1,0) nano FROM sm_merged sm
 JOIN prod_eldoria.core.FACT_PNM_ORDERS fpo ON fpo.crn = sm.crn LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.Order_ID = fpo.Order_ID WHERE dpo.shifting_type = 'intra_city' AND dpo.package_name IS NOT NULL
), co0 AS (SELECT fpo.crn, DATE(fpo.o_completed_ts) d, IFF(dpo.package_name ILIKE '%Nano%',1,0) nano FROM prod_eldoria.core.FACT_PNM_ORDERS fpo LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.order_id=fpo.order_id WHERE dpo.shifting_type='intra_city' AND dpo.order_status='completed' AND dpo.package_name IS NOT NULL),
esc AS (SELECT esc0.*, seg FROM esc0 JOIN segs ON CASE seg WHEN 'all' THEN TRUE WHEN 'nn' THEN nano=0 ELSE nano=1 END),
co_all AS (SELECT co0.*, seg FROM co0 JOIN segs ON CASE seg WHEN 'all' THEN TRUE WHEN 'nn' THEN nano=0 ELSE nano=1 END),
dmg AS (SELECT DISTINCT c.seg, a.ticket_number id, DATE(a.created_at + INTERVAL '330 min') d FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS a JOIN (SELECT DISTINCT seg, crn FROM co_all) c ON c.crn=a.crn WHERE a.action_taken='Damage form sent' AND a.raised_by='Customer' AND a.crn LIKE '%PNM%'),
sm_c AS (SELECT seg, p.p, COUNT(DISTINCT uuid) n FROM esc JOIN periods p ON esc.d BETWEEN p.s AND p.e GROUP BY 1,2),
dm_c AS (SELECT seg, p.p, COUNT(DISTINCT id) n FROM dmg JOIN periods p ON dmg.d BETWEEN p.s AND p.e GROUP BY 1,2),
co_c AS (SELECT seg, p.p, COUNT(DISTINCT crn) n FROM co_all JOIN periods p ON co_all.d BETWEEN p.s AND p.e GROUP BY 1,2),
t AS (SELECT co_c.seg, co_c.p, (100.0*COALESCE(sm_c.n,0)/co_c.n)::FLOAT sm, COALESCE(sm_c.n,0)::FLOAT sm_n, (100.0*COALESCE(dm_c.n,0)/co_c.n)::FLOAT dmg, COALESCE(dm_c.n,0)::FLOAT dmg_n, co_c.n::FLOAT comp_n
  FROM co_c LEFT JOIN sm_c ON sm_c.p=co_c.p AND sm_c.seg=co_c.seg LEFT JOIN dm_c ON dm_c.p=co_c.p AND dm_c.seg=co_c.seg),
u AS (SELECT * FROM t UNPIVOT (val FOR metric IN (sm, sm_n, dmg, dmg_n, comp_n))),
{{FINAL3}}
