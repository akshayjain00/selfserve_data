-- -> data/esc.txt (single string). SM % has no RAG; Damage numerator = damage tickets on intra-city completed non-Nano orders, by ticket date
WITH {{PERIODS}}, sm_data AS (
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
), esc AS (
 SELECT DISTINCT trim(sm.crn)||' - '||trim(sm.Key_reason) AS uuid, sm.ticket_ts d FROM sm_merged sm
 JOIN prod_eldoria.core.FACT_PNM_ORDERS fpo ON fpo.crn = sm.crn LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.Order_ID = fpo.Order_ID WHERE dpo.shifting_type = 'intra_city' AND {{NANO:dpo.package_name ILIKE '%Nano%'}}
), co_all AS (SELECT fpo.crn, DATE(fpo.o_completed_ts) d FROM prod_eldoria.core.FACT_PNM_ORDERS fpo LEFT JOIN prod_eldoria.core.DIM_PNM_ORDERS dpo ON dpo.order_id=fpo.order_id WHERE dpo.shifting_type='intra_city' AND dpo.order_status='completed' AND {{NANO:dpo.package_name ILIKE '%Nano%'}}),
dmg AS (SELECT DISTINCT a.ticket_number id, DATE(a.created_at + INTERVAL '330 min') d FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS a JOIN (SELECT DISTINCT crn FROM co_all) c ON c.crn=a.crn WHERE a.action_taken='Damage form sent' AND a.raised_by='Customer' AND a.crn LIKE '%PNM%'),
sm_c AS (SELECT p.p, COUNT(DISTINCT uuid) n FROM esc JOIN periods p ON esc.d BETWEEN p.s AND p.e GROUP BY 1),
dm_c AS (SELECT p.p, COUNT(DISTINCT id) n FROM dmg JOIN periods p ON dmg.d BETWEEN p.s AND p.e GROUP BY 1),
co_c AS (SELECT p.p, COUNT(DISTINCT crn) n FROM co_all JOIN periods p ON co_all.d BETWEEN p.s AND p.e GROUP BY 1),
t AS (SELECT co_c.p, (100.0*COALESCE(sm_c.n,0)/co_c.n)::FLOAT sm, COALESCE(sm_c.n,0)::FLOAT sm_n, (100.0*COALESCE(dm_c.n,0)/co_c.n)::FLOAT dmg, COALESCE(dm_c.n,0)::FLOAT dmg_n, co_c.n::FLOAT comp_n
  FROM co_c LEFT JOIN sm_c ON sm_c.p=co_c.p LEFT JOIN dm_c ON dm_c.p=co_c.p),
u AS (SELECT * FROM t UNPIVOT (val FOR metric IN (sm, sm_n, dmg, dmg_n, comp_n)))
{{FINAL}};
