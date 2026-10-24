-- -> data/cx.txt  (Completion Score: shifting_ts_ist basis; NPS/Detractors: order_completed_ts_ist basis; VENDOR_BUCKET_TYPE from PNM_EXPERIENCE)
WITH {{PERIODS}}, e AS (SELECT *, COALESCE(vendor_bucket_type,'Unknown') bk FROM PROD_ELDORIA.MART.PNM_EXPERIENCE WHERE shifting_type='intra_city' AND {{NANO:package_name ILIKE 'Nano%'}}),
e2 AS (SELECT *, 'Overall' g FROM e UNION ALL SELECT *, bk FROM e),
cs AS (SELECT p.p, g, 'comp' m, (100.0*COUNT(DISTINCT IFF(order_status='completed',order_id,NULL))/NULLIF(COUNT(DISTINCT IFF(vendor_id IS NOT NULL,order_id,NULL)),0))::FLOAT val
  FROM e2 JOIN periods p ON e2.shifting_ts_ist::date BETWEEN p.s AND p.e GROUP BY 1,2),
np AS (SELECT p.p, g, COUNT(DISTINCT IFF(classification IS NOT NULL,order_id,NULL)) rated, COUNT(DISTINCT IFF(classification='Promoter',order_id,NULL)) pr, COUNT(DISTINCT IFF(classification='Detractor',order_id,NULL)) de, COUNT(DISTINCT order_id) n
  FROM e2 JOIN periods p ON e2.order_completed_ts_ist::date BETWEEN p.s AND p.e WHERE order_status='completed' GROUP BY 1,2),
u AS (SELECT * FROM cs UNION ALL SELECT p,g,'nps',(100.0*(pr-de)/NULLIF(rated,0))::FLOAT FROM np UNION ALL SELECT p,g,'detr',(100.0*de/NULLIF(n,0))::FLOAT FROM np)
SELECT LISTAGG(m||'.'||g||'|'||NVL(TO_VARCHAR(ROUND(mt,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(ml,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(wt,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(wl,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(b6,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(b3,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(lw,4)),'')||'|'||nm||'|'||NVL(TO_VARCHAR(ROUND(fb6,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(fb3,4)),''), ';') FROM (
 SELECT m, g, MAX(IFF(p='mtd_this',val,NULL)) mt, MAX(IFF(p='mtd_last',val,NULL)) ml, MAX(IFF(p='wtd_this',val,NULL)) wt, MAX(IFF(p='wtd_last',val,NULL)) wl,
  AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),val,NULL)) b6, AVG(IFF(p IN ('m1','m2','m3'),val,NULL)) b3, MAX(IFF(p='lastwk',val,NULL)) lw,
  COUNT(IFF(p IN ('m1','m2','m3','m4','m5','m6'),val,NULL)) nm,
  AVG(IFF(p IN ('f1','f2','f3','f4','f5','f6'),val,NULL)) fb6, AVG(IFF(p IN ('f1','f2','f3'),val,NULL)) fb3 FROM u GROUP BY m,g)
