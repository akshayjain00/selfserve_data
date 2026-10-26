r AS (SELECT seg, metric, MAX(IFF(p='mtd_this',val,NULL)) mt, MAX(IFF(p='mtd_last',val,NULL)) ml, MAX(IFF(p='wtd_this',val,NULL)) wt, MAX(IFF(p='wtd_last',val,NULL)) wl,
  AVG(IFF(p IN ('m1','m2','m3','m4','m5','m6'),val,NULL)) b6, AVG(IFF(p IN ('m1','m2','m3'),val,NULL)) b3, MAX(IFF(p='lastwk',val,NULL)) lw,
  COUNT(IFF(p IN ('m1','m2','m3','m4','m5','m6'),val,NULL)) nm,
  AVG(IFF(p IN ('f1','f2','f3','f4','f5','f6'),val,NULL)) fb6, AVG(IFF(p IN ('f1','f2','f3'),val,NULL)) fb3 FROM u GROUP BY seg, metric),
x AS (SELECT seg, LOWER(metric)||'|'||NVL(TO_VARCHAR(ROUND(mt,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(ml,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(wt,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(wl,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(b6,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(b3,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(lw,4)),'')||'|'||nm||'|'||NVL(TO_VARCHAR(ROUND(fb6,4)),'')||'|'||NVL(TO_VARCHAR(ROUND(fb3,4)),'') rec FROM r)
SELECT (SELECT LISTAGG(rec,';') FROM x WHERE seg='all') a, (SELECT LISTAGG(rec,';') FROM x WHERE seg='nn') b, (SELECT LISTAGG(rec,';') FROM x WHERE seg='nano') c
