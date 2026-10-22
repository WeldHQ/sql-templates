-- core.toast.sales_summary
-- Toast's Sales Summary: orders, guests, gross and net sales, discounts, tax,
-- service charges, tips and refunds.
-- Grain: business date x restaurant x revenue center x dining option.
--
-- Every amount is first summed to the order, then grouped, so the three money
-- sources (selections, service charges, payments) never multiply each other.
--
-- What counts:
--   orders and checks that are neither voided nor deleted
--   selections that are not voided; deferred selections (gift card sales) are
--     kept out of sales and reported as deferred_sales
--   payments that were not voided, denied, cancelled or in error
-- gross_sales is the sum of pre-discount prices, net_sales the sum of prices after
-- discounts, discounts the difference. Refunds are reported separately and are not
-- deducted from net_sales; net_sales_after_refunds does that.
-- check_amount is Toast's own check total before tax, kept as a cross-check: it
-- should be close to net_sales + service_charges + gratuities.

WITH orders AS (
    SELECT *
    FROM {{staging.toast.order}}
    WHERE NOT is_voided AND NOT is_deleted
),

checks AS (
    SELECT c.*
    FROM {{staging.toast.check}} c
    JOIN orders o USING (order_id)
    WHERE NOT c.is_voided AND NOT c.is_deleted
),

selection_totals AS (
    SELECT
        s.order_id,
        SUM(IF(NOT s.is_deferred, s.quantity, 0))             AS items_sold,
        SUM(IF(NOT s.is_deferred, s.pre_discount_price, 0))   AS gross_sales,
        SUM(IF(NOT s.is_deferred, s.price, 0))                AS net_sales,
        SUM(IF(s.is_deferred, s.price, 0))                    AS deferred_sales,
        SUM(s.tax)                                            AS tax,
        SUM(s.refund_amount)                                  AS item_refunds
    FROM {{staging.toast.selection}} s
    JOIN checks c USING (check_id)
    WHERE NOT s.is_voided
    GROUP BY 1
),

charge_totals AS (
    SELECT
        sc.order_id,
        SUM(IF(sc.is_gratuity, 0, sc.charge_amount))  AS service_charges,
        SUM(IF(sc.is_gratuity, sc.charge_amount, 0))  AS gratuities
    FROM {{staging.toast.service_charge}} sc
    JOIN checks c USING (check_id)
    GROUP BY 1
),

payment_totals AS (
    SELECT
        p.order_id,
        SUM(p.amount)          AS payments,
        SUM(p.tip_amount)      AS tips,
        SUM(p.refund_amount)   AS payment_refunds
    FROM {{staging.toast.payment}} p
    JOIN checks c USING (check_id)
    WHERE p.payment_status NOT IN ('VOIDED', 'DENIED', 'CANCELLED', 'ERROR')
    GROUP BY 1
),

check_totals AS (
    SELECT order_id, COUNT(*) AS checks, SUM(amount) AS check_amount
    FROM checks
    GROUP BY 1
)

SELECT
    o.business_date,
    o.restaurant_id,
    r.restaurant_name,
    o.revenue_center_id,
    rc.revenue_center_name,
    o.dining_option_id,
    d.dining_option_name,
    COUNT(*)                                                    AS orders,
    SUM(COALESCE(ct.checks, 0))                                 AS checks,
    SUM(COALESCE(o.guests, 0))                                  AS guests,
    SUM(COALESCE(st.items_sold, 0))                             AS items_sold,
    ROUND(SUM(COALESCE(st.gross_sales, 0)), 2)                  AS gross_sales,
    ROUND(SUM(COALESCE(st.gross_sales, 0) - COALESCE(st.net_sales, 0)), 2) AS discounts,
    ROUND(SUM(COALESCE(st.net_sales, 0)), 2)                    AS net_sales,
    ROUND(SUM(COALESCE(st.item_refunds, 0)), 2)                 AS refunds,
    ROUND(SUM(COALESCE(st.net_sales, 0) - COALESCE(st.item_refunds, 0)), 2) AS net_sales_after_refunds,
    ROUND(SUM(COALESCE(st.deferred_sales, 0)), 2)               AS deferred_sales,
    ROUND(SUM(COALESCE(st.tax, 0)), 2)                          AS tax,
    ROUND(SUM(COALESCE(ch.service_charges, 0)), 2)              AS service_charges,
    ROUND(SUM(COALESCE(ch.gratuities, 0)), 2)                   AS gratuities,
    ROUND(SUM(COALESCE(pt.tips, 0)), 2)                         AS tips,
    ROUND(SUM(COALESCE(pt.payments, 0)), 2)                     AS payments,
    ROUND(SUM(COALESCE(ct.check_amount, 0)), 2)                 AS check_amount
FROM orders o
LEFT JOIN check_totals ct USING (order_id)
LEFT JOIN selection_totals st USING (order_id)
LEFT JOIN charge_totals ch USING (order_id)
LEFT JOIN payment_totals pt USING (order_id)
LEFT JOIN {{staging.toast.restaurant}} r ON r.restaurant_id = o.restaurant_id
LEFT JOIN {{staging.toast.revenue_center}} rc
       ON rc.revenue_center_id = o.revenue_center_id AND rc.restaurant_id = o.restaurant_id
LEFT JOIN {{staging.toast.dining_option}} d
       ON d.dining_option_id = o.dining_option_id AND d.restaurant_id = o.restaurant_id
GROUP BY 1, 2, 3, 4, 5, 6, 7
