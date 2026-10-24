periods AS (
 SELECT 'mtd_this' p,'__MTD_S__'::DATE s,'__R__'::DATE e UNION ALL SELECT 'mtd_last','__ML_S__','__ML_E__' UNION ALL
 SELECT 'wtd_this','__WT_S__','__R__' UNION ALL SELECT 'wtd_last','__WL_S__','__WL_E__' UNION ALL SELECT 'lastwk','__LW_S__','__LW_E__' UNION ALL
 SELECT 'm1','__M1_S__','__M1_E__' UNION ALL SELECT 'm2','__M2_S__','__M2_E__' UNION ALL SELECT 'm3','__M3_S__','__M3_E__' UNION ALL
 SELECT 'm4','__M4_S__','__M4_E__' UNION ALL SELECT 'm5','__M5_S__','__M5_E__' UNION ALL SELECT 'm6','__M6_S__','__M6_E__' UNION ALL
 SELECT 'f1','__F1_S__','__F1_E__' UNION ALL SELECT 'f2','__F2_S__','__F2_E__' UNION ALL SELECT 'f3','__F3_S__','__F3_E__' UNION ALL
 SELECT 'f4','__F4_S__','__F4_E__' UNION ALL SELECT 'f5','__F5_S__','__F5_E__' UNION ALL SELECT 'f6','__F6_S__','__F6_E__'
)
