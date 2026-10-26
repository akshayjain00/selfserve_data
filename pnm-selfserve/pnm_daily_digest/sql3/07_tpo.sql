-- 3-segment version of sql/07_tpo.sql -> save_result.py 07_tpo.sql (2 columns per segment: tpo record, key-TPO string)
WITH {{PERIODS}}, segs AS (SELECT 'all' seg UNION ALL SELECT 'nn' UNION ALL SELECT 'nano'),
o0 AS (SELECT crn, DATE(completed_ts_ist) d, IFF(package_name ILIKE '%Nano%',1,0) nano FROM PROD_ELDORIA.MART.PNM_SUPPORT WHERE shifting_type='intra_city' AND DATE(completed_ts_ist) BETWEEN '__B_S__' AND '__R__'),
o AS (SELECT o0.*, segs.seg FROM o0 JOIN segs ON CASE segs.seg WHEN 'all' THEN TRUE WHEN 'nn' THEN nano=0 ELSE nano=1 END),
k AS (SELECT DISTINCT hst.ticket_number, hst.crn, DATE(hst.created_at + interval '5 hours, 30 minutes') kd FROM PROD_ELDORIA.RAW.SFMS_PUBLIC_HS_TICKETS hst WHERE COALESCE(hst.raised_by,'')!='Detractor' AND DATE(hst.created_at + interval '5 hours, 30 minutes') BETWEEN '__B_S__' AND '__R__'),
op AS (SELECT o.seg, p.p, o.crn FROM o JOIN periods p ON o.d BETWEEN p.s AND p.e),
t AS (SELECT op.seg, op.p, (COUNT(DISTINCT k.ticket_number)/NULLIF(COUNT(DISTINCT op.crn),0))::FLOAT val FROM op LEFT JOIN k ON k.crn=op.crn GROUP BY 1,2),
r AS (SELECT seg, MAX(IFF(p='mtd_this',val,NULL)) mt, MAX(IFF(p='mtd_last',val,NULL)) ml, MAX(IFF(p='wtd_this',val,NULL)) wt, MAX(IFF(p='wtd_last',val,NULL)) wl,
  AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),val,NULL)) b6, AVG(IFF(p IN ('m1','m2','m3'),val,NULL)) b3, MAX(IFF(p='lastwk',val,NULL)) lw,
  COUNT(IFF(p IN ('m1','m2','m3','m4','m5','m6'),val,NULL)) nm,
  AVG(IFF(p IN ('f1','f2','f3','f4','f5','f6'),val,NULL)) fb6, AVG(IFF(p IN ('f1','f2','f3'),val,NULL)) fb3 FROM t GROUP BY seg),
x AS (SELECT seg, 'tpo|'||NVL(TO_VARCHAR(ROUND(mt,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(ml,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(wt,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(wl,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(b6,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(b3,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(lw,4)),'')||'|'||nm||'|'||NVL(TO_VARCHAR(ROUND(fb6,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(fb3,4)),'') rec FROM r),
kp AS (SELECT o.seg, CASE WHEN o.d BETWEEN '__MTD_S__' AND '__R__' THEN 'mtd_this' WHEN o.d BETWEEN '__ML_S__' AND '__ML_E__' THEN 'mtd_last' END mtd_p, o.crn FROM o WHERE o.d >= '__ML_S__'),
kk AS (SELECT kp.seg, kp.mtd_p, COUNT(DISTINCT kp.crn) orders, COUNT(DISTINCT IFF(k.kd >= '__ML_S__', k.ticket_number, NULL)) tkts FROM kp LEFT JOIN k ON k.crn=kp.crn WHERE kp.mtd_p IS NOT NULL GROUP BY 1,2),
kb AS (SELECT seg, LISTAGG(mtd_p||'='||ROUND(tkts/NULLIF(orders,0),4), ',') b FROM kk GROUP BY seg)
SELECT (SELECT rec FROM x WHERE seg='all'), (SELECT b FROM kb WHERE seg='all'), (SELECT rec FROM x WHERE seg='nn'), (SELECT b FROM kb WHERE seg='nn'), (SELECT rec FROM x WHERE seg='nano'), (SELECT b FROM kb WHERE seg='nano')
