SELECT table_catalog, table_schema, table_name, row_count
FROM PROD_CURATED.information_schema.tables WHERE table_name ILIKE '%PTL_FE_EVENTS%'
UNION ALL
SELECT table_catalog, table_schema, table_name, row_count
FROM PROD_ELDORIA.information_schema.tables WHERE table_name ILIKE '%FE_EVENTS%'