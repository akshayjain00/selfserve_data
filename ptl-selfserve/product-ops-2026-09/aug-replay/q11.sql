SELECT card_id, PARSE_JSON(dataset_query):native:query::string AS q
FROM PROD_ELDORIA.raw.metabase_public_report_card WHERE card_id IN (44080, 48919, 39118)