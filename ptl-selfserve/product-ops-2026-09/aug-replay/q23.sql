SELECT PARSE_JSON(dataset_query):stages[0]:native::string AS q
FROM PROD_ELDORIA.raw.metabase_public_report_card WHERE card_id = 48491