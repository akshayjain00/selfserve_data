WITH orders AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) AS month,
        COUNT(DISTINCT a.crn) AS total_orders
    FROM PROD_CURATED.PNM_APPLICATION.ORDERS a
    JOIN PROD_CURATED.PNM_APPLICATION.ORDER_ALLOCATION_INFOS b ON a.id = b.order_id AND b.is_active = true
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE a.crn LIKE '%PNM%'
      AND c.package_name NOT ILIKE '%Nano%'
      AND c.shifting_type = 'intra_city'
      AND DATE_TRUNC('month', DATEADD(minute, 330, b.completed_ts)) = '2026-05-01'
    GROUP BY 1
),
tickets AS (
    SELECT
        DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) AS month,
        COUNT(DISTINCT hst.ticket_number) AS tickets_overall,
        COUNT(DISTINCT CASE WHEN hst.raised_by ILIKE 'Vendor%' THEN hst.ticket_number END) AS tickets_vendor,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                   THEN hst.ticket_number END) AS tickets_pre_trip,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN
                        ('open','supervisor_assigned','supervisor_accepted','vendor_accepted')
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pre_trip_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started')
                   THEN hst.ticket_number END) AS tickets_trip_shift,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created IN ('trip_started','shifting_started')
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_trip_shift_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed'
                   THEN hst.ticket_number END) AS tickets_pickup,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'pickup_completed'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_pickup_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed'
                   THEN hst.ticket_number END) AS tickets_completed,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'completed'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_completed_cust,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled'
                   THEN hst.ticket_number END) AS tickets_cancelled,
        COUNT(DISTINCT CASE WHEN hst.order_status_when_ticket_created = 'cancelled'
                        AND hst.raised_by = 'Customer' THEN hst.ticket_number END) AS tickets_cancelled_cust
    FROM PROD_CURATED.SFMS_PUBLIC.HS_TICKETS hst
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.ORDERS a ON hst.crn = a.crn
    LEFT JOIN PROD_CURATED.PNM_APPLICATION.SHIFTING_REQUIREMENTS c ON a.sr_id = c.id
    WHERE hst.crn LIKE '%PNM%'
      AND hst.hs_package NOT ILIKE '%Nano%'
      AND COALESCE(hst.shifting_type, c.shifting_type) = 'intra_city'
      AND COALESCE(hst.raised_by, '') != 'Detractor'
      AND DATE_TRUNC('month', DATEADD(minute, 330, hst.created_at)) = '2026-05-01'
    GROUP BY 1
)
SELECT
    o.month,
    o.total_orders                                                       AS orders_base,
    ROUND(t.tickets_overall         / NULLIF(o.total_orders, 0), 4) AS tpo_overall,
    ROUND(t.tickets_vendor          / NULLIF(o.total_orders, 0), 4) AS tpo_vendor_raised,
    ROUND(t.tickets_pre_trip        / NULLIF(o.total_orders, 0), 4) AS tpo_pre_trip,
    ROUND(t.tickets_pre_trip_cust   / NULLIF(o.total_orders, 0), 4) AS tpo_pre_trip_customer,
    ROUND(t.tickets_trip_shift      / NULLIF(o.total_orders, 0), 4) AS tpo_trip_shift,
    ROUND(t.tickets_trip_shift_cust / NULLIF(o.total_orders, 0), 4) AS tpo_trip_shift_customer,
    ROUND(t.tickets_pickup          / NULLIF(o.total_orders, 0), 4) AS tpo_pickup,
    ROUND(t.tickets_pickup_cust     / NULLIF(o.total_orders, 0), 4) AS tpo_pickup_customer,
    ROUND(t.tickets_completed       / NULLIF(o.total_orders, 0), 4) AS tpo_completed,
    ROUND(t.tickets_completed_cust  / NULLIF(o.total_orders, 0), 4) AS tpo_completed_customer,
    ROUND(t.tickets_cancelled       / NULLIF(o.total_orders, 0), 4) AS tpo_cancelled,
    ROUND(t.tickets_cancelled_cust  / NULLIF(o.total_orders, 0), 4) AS tpo_cancelled_customer
FROM orders o
LEFT JOIN tickets t ON t.month = o.month
ORDER BY o.month