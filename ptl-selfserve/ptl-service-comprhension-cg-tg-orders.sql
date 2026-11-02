-- ptl_service_comprhension: order ids of Control (CG) and Test (TG) customers
-- for orders placed on/after the customer's first exposure (~21.9k rows).
WITH exposures AS (
    SELECT
        customer_id,
        group_name     AS arm,          -- 'Control' (CG) / 'Test' (TG)
        MIN(timestamp) AS first_exposure_ts
    FROM PROD_CURATED.STATSIG_PROD.EXPOSURES
    WHERE experiment_id = 'ptl_service_comprhension'
      AND customer_id IS NOT NULL
    GROUP BY 1, 2
),
bridge AS (
    -- exposures carry the numeric customer_id; orders use the UUID
    SELECT e.arm, e.first_exposure_ts, d.customer_uuid
    FROM exposures e
    JOIN PROD_ELDORIA.CORE.DIM_CUSTOMERS d
      ON d.customer_id = TRY_TO_NUMBER(e.customer_id)
)
SELECT
    b.arm,
    o.external_id AS order_id           -- CRN number
FROM bridge b
JOIN prod_curated.partload_application.orders o
  ON o.customer_id = b.customer_uuid
 AND o.created_at >= b.first_exposure_ts
ORDER BY b.arm, o.created_at
