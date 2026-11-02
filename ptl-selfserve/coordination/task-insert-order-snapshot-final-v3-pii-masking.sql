-- ============================================================================
-- TASK  PROD_CURATED.PARTLOAD_ANALYTICS.INSERT_ORDER_SNAPSHOT_FINAL_V2
-- Fix: internal-user join mobile -> customer_id (PII masking, 2026-10-05)
--
-- The task has FAILED every run since 16:45 IST 2026-10-05 with
--   100038 Numeric value 'XXXXXX0777' is not recognized
-- because masking turned ORDERS.customer_mobile into a masked string that no
-- longer casts against the NUMBER ptl_internal_users.mobile. Nothing has been
-- written since the 16:30 run; the watermark catches the gap up on first run.
--
-- Only two lines change vs task-insert-order-snapshot-final-v2.sql: the
-- ptl_internal_users join and the is_test CASE.
--
-- RUN (owner role -- the MCP is read-only):
--   1. SELECT GET_DDL('TASK','PROD_CURATED.PARTLOAD_ANALYTICS.INSERT_ORDER_SNAPSHOT_FINAL_V2');  -- rollback copy
--   2. Run this whole file. It ends with ALTER TASK ... RESUME -- do not skip it:
--      CREATE OR REPLACE TASK leaves the task SUSPENDED and the Sheet feed stops silently.
--   3. SHOW TASKS LIKE 'INSERT_ORDER_SNAPSHOT_FINAL_V2' IN SCHEMA PROD_CURATED.PARTLOAD_ANALYTICS;  -- state = started
--      then check TASK_HISTORY after the next quarter-hour for SUCCEEDED.
-- ============================================================================

CREATE OR REPLACE TASK PROD_CURATED.PARTLOAD_ANALYTICS.INSERT_ORDER_SNAPSHOT_FINAL_V2
	warehouse=WH_PROD_ANALYTICS_ADHOC_XS_MC
	schedule='USING CRON 0,15,30,45 6-23 * * * Asia/Kolkata'
	as MERGE INTO prod_curated.partload_analytics.order_snapshot_for_ghseet AS tgt
USING (
    WITH watermark AS (
        SELECT CONVERT_TIMEZONE('Asia/Kolkata', 'UTC', MAX(updated_at)) AS wm
        FROM prod_curated.partload_analytics.order_snapshot_for_ghseet
    ),
    -- an order qualifies for reprocessing if EITHER the order itself changed
    -- OR any of its load_details rows changed (e.g. a weight revision) since
    -- the last successful merge. This is a set of order_ids only — the actual
    -- aggregation below still joins ALL of that order's load_details rows,
    -- unfiltered, so a weight-triggered refresh doesn't drop the customer's
    -- original declaration (or vice versa) out of the aggregation.
    changed_order_ids AS (
        SELECT id AS order_id
        FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
        WHERE TO_TIMESTAMP(updated_at) >= (SELECT wm FROM watermark)
        UNION
        SELECT order_id
        FROM PROD_CURATED.PARTLOAD_APPLICATION.LOAD_DETAILS
        WHERE TO_TIMESTAMP(updated_at) >= (SELECT wm FROM watermark)
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
            -- so it stays self-consistent with the watermark comparison above.
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
            -- 2026-10-05 PII masking (DPDP Phase 1): the mobile join now throws
            -- "Numeric value 'XXXXXX1234' is not recognized" and failed every run from
            -- 16:45 IST. Internal users are keyed on customer_id instead: these 49 ids are
            -- every customer this table flagged is_test='True' before masking (all pure-test).
            -- Frozen list -- new internal users are NOT picked up until ptl_internal_users
            -- gains a customer_id column. Same list as cards 33519 / 49438 / 47372.
            LEFT JOIN (
                SELECT DISTINCT column1 AS customer_id FROM VALUES ('073cfdd8-edc4-423b-b343-1efe71dcccbf'),('0b4c3c3a-53e2-40d3-83a9-66f6da2dbe0f'),('0ef05f6c-270e-4675-bdb2-a7df369ab72d'),('182b74bd-5648-48f0-988d-dbaccfb9200c'),('25462efd-8ccb-47b6-b981-68a87bb0cc12'),('25d5b1e5-494f-4ce2-9215-b39419d4527a'),('2c79aac9-792b-4c37-a199-2d1bfb7f2f81'),('2ddcadd5-3cad-42ef-88b6-aad59a4e30ac'),('30f3725e-93f2-419f-899e-929834be3b57'),('4267a75a-4600-40a5-93ef-dfcffaf3b21b'),('4642b009-0611-44a0-b809-af36552b0d8a'),('4c6fbbea-e41c-42f4-861f-5702e1611266'),('4cd097ed-af8d-41a0-9bec-271361bf2784'),('4f24f6fe-5e39-4297-8d0a-c505d6aca493'),('530f1aac-ba01-4901-b1ad-ddc04547ed41'),('550e8400-e29b-41d4-a716-446655440000'),('5f7df6cb-8f91-41bb-87ed-57a4c2281ac6'),('603449ca-c031-4874-be7a-5980cb2a9c5d'),('605568ee-1380-432b-b313-965099aacff1'),('664d2a18-8fcf-4608-9c7f-36596d7f4df1'),('7ac76a96-815c-47be-90da-c0e5602b7f69'),('7cbc287e-246d-42a1-966c-d26815cf1ed3'),('881d35e8-dc49-466d-823d-f16c0e5b36f9'),('88da4c9c-401f-4327-bd91-322f4ac95efb'),('8a540f61-2db3-41a7-958c-daf11d14065a'),('8b53ab43-2753-466b-9c35-3a276fe55e35'),('914963d4-08ab-4469-a301-98847b91890f'),('9b7974e4-eaf1-48f5-9b6a-a79dead94d50'),('9f35ac5f-9460-4457-8aa6-3326ddbc532a'),('a6d0b158-226c-4e4d-9062-711de4e0b154'),('acffd790-c40f-4471-8cb3-379f1b41dd3f'),('ad912f92-17cb-4b1e-bc66-aa5fb10d91c4'),('b06db81e-a136-4650-b1f0-a82420b5eccb'),('b84ffe01-dfd2-477b-84e5-b0c0c3c135b7'),('bdc1b2e8-80d0-4970-b216-f7fa549359e9'),('bf02abf4-8b40-4943-997a-a0867780f1df'),('c0148607-c9d2-4aca-ba75-b5e10e20c367'),('d09d4936-5116-4107-9f4a-eb9845fc05a1'),('d54a393c-ac42-418a-8745-391b9c2c4329'),('d6ae129d-14b1-4e8c-8d00-0d9c734242c2'),('d7af20ed-034c-43e3-a32d-bd42dd7008a8'),('d9e04048-9dcc-4bd3-b69e-6fd6d3b4e1a5'),('da9acad5-3a9d-4e99-ac66-bb9c6d57ad32'),('e3c611c7-bd26-4971-8426-b7a9bf11c9bd'),('f4d5ce95-8658-4e59-b906-2b408da6b9ee'),('f61d6f87-c0b7-4ab3-86e5-2a33da161692'),('fb53b91e-167b-4dc2-a548-e68adb476ee6'),('fcc15d86-8151-411a-8934-37fd3dc1c1f6'),('fddfff04-af92-4ad1-abf7-2472a5e445ea')
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

ALTER TASK PROD_CURATED.PARTLOAD_ANALYTICS.INSERT_ORDER_SNAPSHOT_FINAL_V2 RESUME;
