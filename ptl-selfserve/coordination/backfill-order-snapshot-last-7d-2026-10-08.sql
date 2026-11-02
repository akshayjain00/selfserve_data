-- ============================================================================
-- ONE-TIME BACKFILL  order_snapshot_for_ghseet  -- last 7 days  (2026-10-08)
--
-- Re-merges every order created in the last 7 IST days (2026-10-01 .. today) through the
-- task's own SELECT (v4: is_test from ptl_internal_users.customer_uuid). ALL columns are
-- refreshed. Expected on 2026-10-08: 4 rows flip is_test False->True, 7 live orders not
-- yet in the snapshot get inserted, the rest rewrite identical values.
--
-- Watermark-safe: src.updated_at is each order's real last change, never newer than the
-- current MAX(updated_at), so the scheduled task's next run is unaffected.
-- Idempotent: re-running rewrites the same values.
-- Run as the table owner; the Snowflake MCP is read-only (!399517!).
-- ============================================================================

-- STEP A (read-only) -- what will change, by is_test flag:
WITH tbl AS (SELECT DISTINCT customer_uuid AS cid FROM PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
             UNION SELECT column1 FROM VALUES ('550e8400-e29b-41d4-a716-446655440000'),('da9acad5-3a9d-4e99-ac66-bb9c6d57ad32')),
live AS (
    SELECT o.id AS order_id, IFF(t.cid IS NULL, 'False', 'True') AS new_flag
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o
    LEFT JOIN tbl t ON t.cid = o.customer_id
    WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(o.created_at))::date
          >= DATEADD('day', -7, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::date)
)
SELECT s.is_test AS current_flag, l.new_flag, COUNT(*) AS n
FROM live l LEFT JOIN prod_curated.partload_analytics.order_snapshot_for_ghseet s ON s.order_id::int = l.order_id
GROUP BY 1, 2 ORDER BY 1, 2;
-- expect: False/False ~3861, False/True 4, True/True 33, NULL/False 7 (not yet in snapshot)

-- STEP B -- the backfill:
MERGE INTO prod_curated.partload_analytics.order_snapshot_for_ghseet AS tgt
USING (
    WITH
    -- BACKFILL: every order created in the last 7 IST days (today included), whether
    -- or not it changed. Re-merging through the task's own SELECT refreshes ALL
    -- columns, is_test included.
    changed_order_ids AS (
        SELECT id AS order_id
        FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
        WHERE CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(created_at))::date
              >= DATEADD('day', -7, CONVERT_TIMEZONE('Asia/Kolkata', CURRENT_TIMESTAMP())::date)
    ),
    final AS (
        SELECT
            orders.id AS order_id,
            CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))::date AS dated,
            external_id,
            CASE
                WHEN ORDERS.state = 0 THEN 'Open'
                WHEN ORDERS.state = 1 THEN 'Assigned'
                WHEN ORDERS.state = 2 THEN 'Picked_up'
                WHEN ORDERS.state = 3 THEN 'Completed'
                WHEN ORDERS.state = 4 THEN 'Cancelled'
            END AS order_status,
            CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at)) AS created_at,
            -- reflects the last time EITHER the order or its load_details changed,
            -- so it stays self-consistent with the scheduled task's watermark.
            -- Both sides must be MAX()-wrapped: this expression contains an
            -- aggregate, so GROUP BY ALL will NOT treat a bare ORDERS.updated_at
            -- here as a grouping key (compile error). The inner COALESCE guards
            -- against GREATEST returning NULL when an order has no load_details
            -- rows at all -- a NULL here would corrupt the stored watermark.
            GREATEST(
                MAX(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at))),
                COALESCE(
                    MAX(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(load_details.updated_at))),
                    MAX(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at)))
                )
            ) AS updated_at,
            date(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.pickup_slot_start))) AS pick_up_date,
            TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.pickup_slot_start)), 'HH24:MI')
                || ' - ' ||
            TO_CHAR(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.pickup_slot_end)), 'HH24:MI') AS pickup_slot,
            CONCAT(pickup_lat, ' , ', pickup_lng) AS pickup_lat_lng,
            CONCAT(drop_lat, ' , ', drop_lng) AS drop_lat_lng,
            ROUND(MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED' THEN load_details.chargeable_weight END) / 1000, 0) AS customer_declared_weight,
            ROUND(MAX(CASE WHEN load_details.entry_type = 'OPS_DECLARED' AND load_details.is_active = TRUE THEN load_details.chargeable_weight END) / 1000, 0) AS ops_declared_weight,
            COALESCE(
                MAX(CASE WHEN load_details.entry_type = 'OPS_DECLARED' AND load_details.is_active = TRUE THEN material_type.display_name END),
                MAX(CASE WHEN load_details.entry_type = 'CUSTOMER_DECLARED' THEN material_type.display_name END)
            ) AS goods_type,
            customer_name AS booker_name,
            customer_mobile AS booker_mobile_no,
            MAX(CASE WHEN contact_details.type = 0 THEN contact_details.name END) AS sender_name,
            MAX(CASE WHEN contact_details.type = 0 THEN contact_details.mobile END) AS sender_mobile,
            MAX(CASE WHEN contact_details.type = 1 THEN contact_details.name END) AS receiver_name,
            MAX(CASE WHEN contact_details.type = 1 THEN contact_details.mobile END) AS receiver_mobile,
            MAX(CASE WHEN contact_details.type = 0 THEN contact_details.address_line END) AS pickup_address,
            MAX(CASE WHEN contact_details.type = 1 THEN contact_details.address_line END) AS drop_address,
            CASE WHEN ptl_internal_users.customer_id IS NULL THEN 'False' ELSE 'True' END AS is_test,
            driver_name,
            driver_mobile,
            VEHICLE_REGISTRATION_NUMBER,
            vehicle_type,
            round(estimated_fare / 100, 0) AS final_fare,
            round(coalesce(max(CASE WHEN order_fares.fare_reason_code = 'INITIAL_BOOKING' THEN (total_fare / 100) END), MAX(estimated_fare / 100)), 0) AS customer_upfront_fare,
            max(CASE WHEN order_fares.fare_reason_code = 'WEIGHT_REVISION_CHANGE' AND load_details.is_active = TRUE THEN round(total_fare / 100, 0) END) AS ops_declared_fare,
            CASE WHEN payment_status = 0 THEN 'Pending' ELSE 'Completed' END AS payment_status,
            customers.email,
            batch_id,
            -- 2026-09-07: route lookup moved to the CDC table
            -- PROD_CURATED.PARTLOAD_APPLICATION.ROUTES. ptl_routes is hand-
            -- maintained, stops at route id 96 and had not been written since
            -- 2026-06-03, so routes 97/98 stored a NULL route_name (26 rows).
            --
            -- The CASE maps 4 CDC labels back to the spellings already present
            -- in this table's 120k rows. Do NOT remove it: without it, changed
            -- orders would store 'Bangalore - Mysore' while 7,075 untouched
            -- historical rows keep 'Bangalore - Mysuru', splitting one route
            -- into two in the Google Sheet. The cards do not need this because
            -- they recompute in full on every run; a MERGE target does.
            --
            -- The COALESCE fallback exists for route 52 'Bangalore -
            -- Tiruvallur', which ptl_routes has but the CDC table does not
            -- (the one gap in ids 1..98). Without it that route's name blanks.
            COALESCE(
                REPLACE(CASE r.route_label
                    WHEN 'Bangalore-Mysore'       THEN 'Bangalore-Mysuru'
                    WHEN 'Bangalore-HubliDharwad' THEN 'Bangalore-Hubli_Dharwad'
                    WHEN 'Bangalore-Bellari'      THEN 'Bangalore-Bellary'
                    WHEN 'Bangalore-Devanagere'   THEN 'Bangalore-Davanagere'
                    ELSE r.route_label
                END, '-', ' - '),
                ptl_routes.route_name
            ) AS route_name,
            (CASE WHEN orders.state = '3' THEN date(orders.updated_at + interval '330 minutes') ELSE NULL END) AS delivery_date,
            (
                SELECT COUNT_IF(o2.state = 3)
                FROM PROD_CURATED.PARTLOAD_APPLICATION.orders o2
                WHERE o2.customer_id = orders.customer_id
                AND (o2.created_at < orders.created_at OR (o2.created_at = orders.created_at AND o2.id <= orders.id))
            ) AS customer_lto,
            ROUND(quotations.discount_amount_minor_units / 100, 0) AS discount,
            ROUND(estimated_fare / 100, 0) + ROUND(COALESCE(quotations.discount_amount_minor_units, 0) / 100, 0) AS total_fare_without_discount
        FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
            JOIN changed_order_ids c ON c.order_id = orders.id
            LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.contact_details ON ORDERS.id = contact_details.order_id
            LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS ON ORDERS.id = LOAD_DETAILS.order_id
            LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.material_type ON LOAD_DETAILS.material_type_id = material_type.material_type_id
            LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDER_VEHICLES ON ORDERS.external_id = ORDER_VEHICLES.order_external_id AND order_vehicles.is_active = TRUE
            -- is_test: keyed on ptl_internal_users.customer_uuid (column added after the
            -- 2026-10-05 PII masking; replaces the frozen 49-id list). Live lookup, so a
            -- new internal user flags their orders from the next time the order is merged.
            -- The two ids in the UNION are in the old frozen list but absent from the table
            -- (7 historic test orders, May-Jul 2025) -- kept so they do not flip to 'False'
            -- if CDC ever touches them. Drop the UNION once the table owner adds them.
            LEFT JOIN (
                SELECT DISTINCT customer_uuid AS customer_id
                FROM PROD_CURATED.PARTLOAD_ANALYTICS.ptl_internal_users
                WHERE customer_uuid IS NOT NULL
                UNION
                SELECT column1 FROM VALUES ('550e8400-e29b-41d4-a716-446655440000'),('da9acad5-3a9d-4e99-ac66-bb9c6d57ad32')
            ) ptl_internal_users ON ptl_internal_users.customer_id = ORDERS.customer_id
            LEFT JOIN prod_curated.oms_public.customers ON customers.uuid = orders.customer_id
            -- primary route source: CDC, 1 row per route id, no dedupe predicate needed
            LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ROUTES r
                   ON r.id = orders.route_id
            -- fallback only (route 52). is_active IS required here: ptl_routes
            -- holds 132 rows for 96 ids and without it this join fans out on 35
            -- of them. Harmless today only because no route has conflicting
            -- names across its duplicate rows.
            LEFT JOIN partload_analytics.ptl_routes
                   ON ptl_routes.route_id = orders.route_id
                  AND ptl_routes.is_active = 'True'
            LEFT JOIN (
                SELECT * FROM PROD_CURATED.PARTLOAD_APPLICATION.batched_orders_v1
                QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) = 1
            ) bo ON bo.order_id = orders.id
            LEFT JOIN prod_curated.partload_application.order_fares ON ARRAY_CONTAINS(load_details.id, order_fares.load_details_ids)
            LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.QUOTATIONS quotations ON orders.quotation_uuid = quotations.quotation_uuid
        GROUP BY ALL
        -- NOTE: the ORDER BY must spell the expression out in full rather than
        -- referencing the `updated_at` alias -- a bare `updated_at` here is
        -- ambiguous against the raw updated_at columns on the joined tables.
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY orders.external_id
            ORDER BY GREATEST(
                MAX(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at))),
                COALESCE(
                    MAX(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(load_details.updated_at))),
                    MAX(CONVERT_TIMEZONE('UTC', 'Asia/Kolkata', TO_TIMESTAMP(ORDERS.updated_at)))
                )
            ) DESC
        ) = 1
        ORDER BY 1
    )
    SELECT * FROM final
) AS src ON tgt.external_id = src.external_id
WHEN MATCHED THEN UPDATE SET
    tgt.order_id = src.order_id,
    tgt.dated = src.dated,
    tgt.order_status = src.order_status,
    tgt.created_at = src.created_at,
    tgt.updated_at = src.updated_at,
    tgt.pick_up_date = src.pick_up_date,
    tgt.pickup_slot = src.pickup_slot,
    tgt.pickup_lat_lng = src.pickup_lat_lng,
    tgt.drop_lat_lng = src.drop_lat_lng,
    tgt.customer_declared_weight = src.customer_declared_weight,
    tgt.ops_declared_weight = src.ops_declared_weight,
    tgt.goods_type = src.goods_type,
    tgt.booker_name = src.booker_name,
    tgt.booker_mobile_no = src.booker_mobile_no,
    tgt.sender_name = src.sender_name,
    tgt.sender_mobile = src.sender_mobile,
    tgt.receiver_name = src.receiver_name,
    tgt.receiver_mobile = src.receiver_mobile,
    tgt.pickup_address = src.pickup_address,
    tgt.drop_address = src.drop_address,
    tgt.is_test = src.is_test,
    tgt.driver_name = src.driver_name,
    tgt.driver_mobile = src.driver_mobile,
    tgt.vehicle_registration_number = src.vehicle_registration_number,
    tgt.vehicle_type = src.vehicle_type,
    tgt.final_fare = src.final_fare,
    tgt.customer_upfront_fare = src.customer_upfront_fare,
    tgt.ops_declared_fare = src.ops_declared_fare,
    tgt.payment_status = src.payment_status,
    tgt.email = src.email,
    tgt.batch_id = src.batch_id,
    tgt.route_name = src.route_name,
    tgt.delivery_date = src.delivery_date,
    tgt.customer_lto = src.customer_lto,
    tgt.discount = src.discount,
    tgt.total_fare_without_discount = src.total_fare_without_discount
WHEN NOT MATCHED THEN INSERT (
    order_id, dated, external_id, order_status, created_at, updated_at,
    pick_up_date, pickup_slot, pickup_lat_lng, drop_lat_lng,
    customer_declared_weight, ops_declared_weight, goods_type,
    booker_name, booker_mobile_no, sender_name, sender_mobile,
    receiver_name, receiver_mobile, pickup_address, drop_address,
    is_test, driver_name, driver_mobile, vehicle_registration_number,
    vehicle_type, final_fare, customer_upfront_fare, ops_declared_fare,
    payment_status, email, batch_id, route_name, delivery_date, customer_lto,
    discount, total_fare_without_discount
)
VALUES (
    src.order_id, src.dated, src.external_id, src.order_status, src.created_at, src.updated_at,
    src.pick_up_date, src.pickup_slot, src.pickup_lat_lng, src.drop_lat_lng,
    src.customer_declared_weight, src.ops_declared_weight, src.goods_type,
    src.booker_name, src.booker_mobile_no, src.sender_name, src.sender_mobile,
    src.receiver_name, src.receiver_mobile, src.pickup_address, src.drop_address,
    src.is_test, src.driver_name, src.driver_mobile, src.vehicle_registration_number,
    src.vehicle_type, src.final_fare, src.customer_upfront_fare, src.ops_declared_fare,
    src.payment_status, src.email, src.batch_id, src.route_name, src.delivery_date, src.customer_lto,
    src.discount, src.total_fare_without_discount
);
