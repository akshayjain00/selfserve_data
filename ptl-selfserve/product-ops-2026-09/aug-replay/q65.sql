WITH total_orders AS (
    SELECT DATE_TRUNC('month', CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))) AS period,
           COUNT(DISTINCT id) AS placed_orders,
           COUNT(DISTINCT CASE WHEN orders.state = 3 THEN id END) AS completed_orders
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDERS
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = ORDERS.customer_mobile
    WHERE ptl_internal_users.mobile IS NULL
      AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(ORDERS.created_at))::date BETWEEN DATE '2026-06-01' AND DATE '2026-08-31'
    GROUP BY 1
),
base AS (
    SELECT o.id AS order_id, ocr.reason,
           CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at)) AS order_created_at_ist,
           TRIM(REGEXP_REPLACE(LOWER(ocr.reason),'[:]+$','')) AS normalized_reason
    FROM PROD_CURATED.PARTLOAD_APPLICATION.ORDER_CANCELLATION_REASONS ocr
    LEFT JOIN PROD_CURATED.PARTLOAD_APPLICATION.ORDERS o ON ocr.order_external_id = o.external_id
    LEFT JOIN PROD_CURATED.PARTLOAD_ANALYTICS.PTL_INTERNAL_USERS ON PTL_INTERNAL_USERS.mobile = o.customer_mobile
    WHERE o.state = 4 AND ptl_internal_users.mobile IS NULL
      AND CONVERT_TIMEZONE('UTC','Asia/Kolkata', TO_TIMESTAMP(o.created_at))::date BETWEEN DATE '2026-06-01' AND DATE '2026-08-31'
),
rb AS (SELECT order_id, reason, order_created_at_ist,
         CASE WHEN normalized_reason ILIKE 'other%' OR normalized_reason ILIKE 'अन्य%' OR normalized_reason IN ('na','n/a')
              THEN 'text box' ELSE normalized_reason END AS sr FROM base),
mapped AS (
  SELECT order_id, order_created_at_ist,
    CASE
      WHEN sr IN ('change of mind','shipment not ready','customer not responding','booked by mistake',
                  'not ready to pay wd charges','address issues','not available at drop location',
                  'cancelling as seized by tax officials') THEN 'Customer'
      WHEN sr IN ('want to reschedule order','need faster pickup','vehicle not allocated yet',
                  'found better price elsewhere','ops requested cancellation','need larger vehicle',
                  'need helper','supply issue') THEN 'Porter'
      WHEN sr IN ('partner denied to pickup','unable to contact partner','vehicle breakdown',
                  'partner demanding extra money') THEN 'Partner'
      WHEN sr='text box' AND (reason ILIKE '%test%' OR reason ILIKE '%mistake%' OR reason ILIKE '%demo%') THEN 'Customer'
      WHEN sr='text box' AND (reason ILIKE '%mind%' OR reason ILIKE '%shipment%' OR reason ILIKE '%double%' OR reason ILIKE '%dummy%' OR reason ILIKE '%twice%' OR reason ILIKE '%address%' OR reason ILIKE '%change%' OR reason ILIKE '%checking%' OR reason ILIKE '%response%' OR reason ILIKE '%wrong%' OR reason ILIKE '%fake%' OR reason ILIKE '%2 order%') THEN 'Customer'
      WHEN sr='text box' AND ((reason ILIKE '%customer%' OR reason ILIKE '%cx%') AND (reason ILIKE '%unavailable%' OR reason ILIKE '%connect%' OR reason ILIKE '%cancel%' OR reason ILIKE '%change%' OR reason ILIKE '%request%' OR reason ILIKE '%not%')) THEN 'Customer'
      WHEN sr='text box' AND (reason ILIKE '%large%' OR reason ILIKE '%vehicle%' OR reason ILIKE '%capacity%' OR reason ILIKE '%size%' OR reason ILIKE '%bigger%' OR reason ILIKE '%small%' OR reason ILIKE '%supply%' OR reason ILIKE '%reschedule%') THEN 'Porter'
      WHEN sr='text box' AND (reason ILIKE '%separate%' OR reason ILIKE '%full%' OR reason ILIKE '%dedicated%' OR reason ILIKE '%exclusive%' OR reason ILIKE '%ftl%') THEN 'Customer'
      WHEN sr='text box' AND (reason ILIKE '%ops%' OR reason ILIKE '%operation%' OR reason ILIKE '%partner%' OR reason ILIKE '%availability%' OR reason ILIKE '%fleet%' OR reason ILIKE '%available%' OR reason ILIKE '%driver%' OR reason ILIKE '%not picked%' OR reason ILIKE '%rude%') THEN 'Partner'
      WHEN sr='text box' AND (reason ILIKE '%fast%' OR reason ILIKE '%urgent%' OR reason ILIKE '%time%' OR reason ILIKE '%delay%' OR reason ILIKE '%schedule%' OR reason ILIKE '%slot%' OR reason ILIKE '%pickup%' OR reason ILIKE '%delivery%' OR reason ILIKE '%late%') THEN 'Partner'
      WHEN sr='text box' AND (reason ILIKE '%extra%' OR reason ILIKE '%money%' OR reason ILIKE '%rate%' OR reason ILIKE '%fare%' OR reason ILIKE '%price%' OR reason ILIKE '%cost%' OR reason ILIKE '%charge%' OR reason ILIKE '%payment%' OR reason ILIKE '%expensive%' OR reason ILIKE '%cheap%' OR reason ILIKE '%amount%') THEN 'Porter'
      WHEN sr='text box' AND (reason ILIKE '%address%' OR reason ILIKE '%location%' OR reason ILIKE '%pin%' OR reason ILIKE '%area%' OR reason ILIKE '%zone%' OR reason ILIKE '%distance%' OR reason ILIKE '%route%' OR reason ILIKE '%pickup%' OR reason ILIKE '%drop%' OR reason ILIKE '%wd%') THEN 'Customer'
      WHEN sr='text box' AND (reason ILIKE '%helper%' OR reason ILIKE '%labour%' OR reason ILIKE '%loading%' OR reason ILIKE '%unloading%' OR reason ILIKE '%loader%' OR reason ILIKE '%handling%' OR reason ILIKE '%service%' OR reason ILIKE '%assistance%' OR reason ILIKE '%packing%' OR reason ILIKE '%load assist%') THEN 'Porter'
      WHEN sr='text box' AND (reason ILIKE '%item%' OR reason ILIKE '%product%' OR reason ILIKE '%material%' OR reason ILIKE '%goods%' OR reason ILIKE '%cargo%' OR reason ILIKE '%fragile%' OR reason ILIKE '%heavy%' OR reason ILIKE '%weight%') THEN 'Porter'
      WHEN sr='text box' AND (reason ILIKE '%app%' OR reason ILIKE '%technical%' OR reason ILIKE '%system%' OR reason ILIKE '%error%' OR reason ILIKE '%bug%' OR reason ILIKE '%problem%') THEN 'Porter'
      WHEN sr='text box' AND (reason ILIKE '%duplicate%' OR reason ILIKE '%multiple%' OR reason ILIKE '%repeat%' OR reason ILIKE '%already%' OR reason ILIKE '%again%') THEN 'Customer'
      ELSE 'Others' END AS major_category
  FROM rb
),
cc AS (SELECT DATE_TRUNC('month', order_created_at_ist) AS period,
              COUNT(DISTINCT CASE WHEN major_category='Customer' THEN order_id END) AS customer_cancellations
       FROM mapped GROUP BY 1)
SELECT t.period::DATE AS period, t.placed_orders, t.completed_orders,
       ROUND(100.0*t.completed_orders/NULLIF(t.placed_orders - COALESCE(cc.customer_cancellations,0),0),2) AS effective_ff_pct
FROM total_orders t LEFT JOIN cc ON t.period = cc.period ORDER BY 1