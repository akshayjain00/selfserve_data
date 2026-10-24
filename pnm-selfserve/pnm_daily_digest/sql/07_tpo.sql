-- -> data/tpo.txt = col A + ';k_tpo|<mtd_this>|<mtd_last>||||||' from col B (B returns 'mtd_last=x,mtd_this=y')
WITH {{PERIODS}}, o AS (SELECT crn, DATE(completed_ts_ist) d FROM PROD_ELDORIA.MART.PNM_SUPPORT WHERE {{NANO:package_name ILIKE '%Nano%'}} AND shifting_type='intra_city' AND DATE(completed_ts_ist) BETWEEN '__B_S__' AND '__R__'),
k AS (SELECT DISTINCT hst.ticket_number, hst.crn FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst WHERE COALESCE(hst.raised_by,'')!='Detractor' AND DATE(hst.created_at + interval '5 hours, 30 minutes') BETWEEN '__B_S__' AND '__R__'),
op AS (SELECT p.p, o.crn FROM o JOIN periods p ON o.d BETWEEN p.s AND p.e),
t AS (SELECT op.p, (COUNT(DISTINCT k.ticket_number)/NULLIF(COUNT(DISTINCT op.crn),0))::FLOAT val, 'tpo' metric FROM op LEFT JOIN k ON k.crn=op.crn GROUP BY 1),
u AS (SELECT p, metric, val FROM t)
SELECT ({{FINAL}}) a,
 (WITH orders_p AS (
    SELECT crn, CASE WHEN DATE(completed_ts_ist) BETWEEN '__MTD_S__' AND '__R__' THEN 'mtd_this' WHEN DATE(completed_ts_ist) BETWEEN '__ML_S__' AND '__ML_E__' THEN 'mtd_last' END AS mtd_p
    FROM PROD_ELDORIA.MART.PNM_SUPPORT WHERE {{NANO:package_name ILIKE '%Nano%'}} AND shifting_type = 'intra_city' AND DATE(completed_ts_ist) BETWEEN '__ML_S__' AND '__R__'
  ), tkt_p AS (
    SELECT hst.ticket_number, o.mtd_p FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst JOIN orders_p o ON hst.crn = o.crn
    WHERE COALESCE(hst.raised_by,'')!='Detractor' AND DATE(hst.created_at + interval '5 hours, 30 minutes') BETWEEN '__ML_S__' AND '__R__')
  SELECT LISTAGG(o.mtd_p||'='||ROUND(NVL(t.tkts,0)/NULLIF(o.orders,0),4), ',') FROM (SELECT mtd_p, COUNT(DISTINCT crn) orders FROM orders_p WHERE mtd_p IS NOT NULL GROUP BY 1) o
  LEFT JOIN (SELECT mtd_p, COUNT(DISTINCT ticket_number) tkts FROM tkt_p WHERE mtd_p IS NOT NULL GROUP BY 1) t ON t.mtd_p=o.mtd_p) b;
