"""Re-key the 13 order-level cards off masked mobile onto customer_id (PII masking, 2026-10-05)."""
REPL = [
    ("    SELECT REGEXP_REPLACE(customer_mobile::varchar,'[^0-9]','')     AS mobile,",
     "    SELECT customer_id                                               AS customer_uuid,"),
    ("           ON fc.mobile = REGEXP_REPLACE(o.customer_mobile::varchar,'[^0-9]','')",
     "           ON fc.customer_uuid = o.customer_id"),
    ("      AND o.customer_mobile NOT IN (\n            SELECT DISTINCT mobile FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS)",
     "      AND o.customer_id NOT IN (   -- keyed on customer_uuid: mobile is masked since 2026-10-05\n            SELECT customer_uuid FROM PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS\n            WHERE customer_uuid IS NOT NULL)"),
]
def rekey(sql: str) -> str:
    for old, new in REPL:
        assert sql.count(old) == 1, old[:60]
        sql = sql.replace(old, new)
    assert "mobile" not in sql.replace("mobile is masked", "")
    return sql
