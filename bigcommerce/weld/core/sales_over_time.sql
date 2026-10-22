-- core.bigcommerce.sales_over_time
-- The sales equation per order per day, with refunds
-- on the day they were made.
--
-- Grain: day x store x order x row type. Row type is SALE (the order, on the day it
-- was placed) or RETURN (refunds, on the day they were issued). Keeping it in the
-- grain means an order that sells and refunds produces separate rows, so both sides
-- stay auditable. Aggregate to day in BI.
--
-- Currency: the order's own (currency_code), which is in the grain via the order.
-- Do not sum across currencies in a multi-currency store without converting first.
-- Timezone: staging.bigcommerce.store.report_timezone.
--
-- Depends on: staging.bigcommerce.order, .refund, .refund_line_item,
--             .refund_payment, .channel, .store
--
-- WHICH ORDERS COUNT. Dropped: Incomplete (0, an abandoned checkout that never
-- became an order), Cancelled (5), Declined (6, payment failed) and archived
-- orders. Everything else stays, including Pending and Awaiting Payment, because
-- BigCommerce has created the order and the merchant usually expects to be paid;
-- status is passed through so BI can narrow it. Refunds are kept only for orders
-- that are kept, so a refund can never appear without its sale.
--
-- THE SALES EQUATION. Discounts are not taken from discount_amount or
-- coupon_discount: the API documents neither precisely enough to know whether one
-- contains the other. They are derived from BigCommerce's own totals instead,
--     discounts = total_ex_tax - subtotal_ex_tax - shipping - handling - wrapping
-- which makes total_sales on a SALE row equal BigCommerce's total_inc_tax by
-- construction. Both reported discount columns are passed through for comparison.

WITH store AS (
    SELECT bigcommerce_store, report_timezone
    FROM {{staging.bigcommerce.store}}
),

orders AS (
    SELECT
        o.*,
        c.channel_name,
        c.channel_type,
        COALESCE(o.billing_country_code, o.geoip_country_code) AS country_code,
        s.report_timezone
    FROM {{staging.bigcommerce.order}} o
    JOIN store s USING (bigcommerce_store)
    LEFT JOIN {{staging.bigcommerce.channel}} c USING (bigcommerce_store, channel_id)
    WHERE COALESCE(o.status_id, -1) NOT IN (0, 5, 6)
      AND NOT o.is_deleted
),

-- A refund whose every payment was declined returned no money. A refund with no
-- payment rows at all (for example one settled outside BigCommerce) is kept.
declined_refunds AS (
    SELECT bigcommerce_store, refund_id
    FROM {{staging.bigcommerce.refund_payment}}
    GROUP BY bigcommerce_store, refund_id
    HAVING LOGICAL_AND(is_declined)
),

-- Pre-aggregated to one row per refund before joining, so the quantity sum cannot
-- fan out the refund's money.
refund_quantities AS (
    SELECT bigcommerce_store, refund_id, SUM(quantity) AS refunded_quantity
    FROM {{staging.bigcommerce.refund_line_item}}
    WHERE item_type = 'PRODUCT'
    GROUP BY bigcommerce_store, refund_id
),

sale_rows AS (
    SELECT
        DATE(o.created_at, o.report_timezone)          AS date,
        o.bigcommerce_store,
        o.order_id,
        'SALE'                                         AS row_type,
        o.subtotal_ex_tax                              AS gross_sales,
        o.total_ex_tax - o.subtotal_ex_tax
            - COALESCE(o.shipping_cost_ex_tax, 0)
            - COALESCE(o.handling_cost_ex_tax, 0)
            - COALESCE(o.wrapping_cost_ex_tax, 0)      AS discounts,
        CAST(0 AS NUMERIC)                             AS returns,
        COALESCE(o.shipping_cost_ex_tax, 0)            AS shipping_charges,
        COALESCE(o.handling_cost_ex_tax, 0)            AS handling_charges,
        COALESCE(o.wrapping_cost_ex_tax, 0)            AS gift_wrapping_charges,
        COALESCE(o.total_tax, 0)                       AS taxes,
        o.items_total                                  AS quantity_ordered,
        0                                              AS quantity_refunded,
        1                                              AS is_order_placed,
        0                                              AS refunds
    FROM orders o
),

return_rows AS (
    SELECT
        DATE(r.created_at, o.report_timezone)          AS date,
        r.bigcommerce_store,
        r.order_id,
        'RETURN'                                       AS row_type,
        CAST(0 AS NUMERIC)                             AS gross_sales,
        CAST(0 AS NUMERIC)                             AS discounts,
        -- Everything refunded, tax excluded. This includes any refunded shipping or
        -- handling: BigCommerce's refund total does not split them reliably,
        -- because quantity-based product refunds carry no amount per line.
        -SUM(COALESCE(r.total_amount, 0) - COALESCE(r.total_tax, 0)) AS returns,
        CAST(0 AS NUMERIC)                             AS shipping_charges,
        CAST(0 AS NUMERIC)                             AS handling_charges,
        CAST(0 AS NUMERIC)                             AS gift_wrapping_charges,
        -SUM(COALESCE(r.total_tax, 0))                 AS taxes,
        0                                              AS quantity_ordered,
        SUM(COALESCE(q.refunded_quantity, 0))          AS quantity_refunded,
        0                                              AS is_order_placed,
        COUNT(*)                                       AS refunds
    FROM {{staging.bigcommerce.refund}} r
    JOIN orders o USING (bigcommerce_store, order_id)
    LEFT JOIN refund_quantities q USING (bigcommerce_store, refund_id)
    LEFT JOIN declined_refunds d USING (bigcommerce_store, refund_id)
    WHERE d.refund_id IS NULL
    GROUP BY 1, 2, 3
),

unioned AS (
    SELECT * FROM sale_rows
    UNION ALL
    SELECT * FROM return_rows
)

SELECT
    u.date,
    u.bigcommerce_store,
    u.order_id,
    u.row_type,

    o.currency_code,
    o.channel_id,
    o.channel_name,
    o.channel_type,
    o.order_source,
    o.status_id,
    o.status,
    o.payment_method,
    o.country_code,
    o.customer_id,
    o.is_digital,
    DATE(o.created_at, o.report_timezone)              AS order_date,

    -- The sales equation. Discounts and returns are negative, so every line below
    -- is plain addition.
    u.gross_sales,
    u.discounts,
    u.returns,
    u.gross_sales + u.discounts + u.returns            AS net_sales,
    u.shipping_charges,
    u.handling_charges,
    u.gift_wrapping_charges,
    u.taxes,
    u.gross_sales + u.discounts + u.returns
        + u.shipping_charges + u.handling_charges
        + u.gift_wrapping_charges                      AS total_sales_ex_tax,
    u.gross_sales + u.discounts + u.returns
        + u.shipping_charges + u.handling_charges
        + u.gift_wrapping_charges + u.taxes            AS total_sales,

    -- BigCommerce's own figures, on SALE rows only, for reconciliation.
    IF(u.row_type = 'SALE', o.total_inc_tax, NULL)      AS reported_total_inc_tax,
    IF(u.row_type = 'SALE', o.discount_amount, NULL)    AS reported_discount_amount,
    IF(u.row_type = 'SALE', o.coupon_discount, NULL)    AS reported_coupon_discount,
    IF(u.row_type = 'SALE', o.gift_certificate_amount, NULL) AS gift_certificate_payments,
    IF(u.row_type = 'SALE', o.store_credit_amount, NULL)     AS store_credit_payments,

    u.quantity_ordered,
    u.quantity_refunded,
    -- One row per order carries 1: sum it over any window for the order count and
    -- the average order value denominator.
    u.is_order_placed,
    u.refunds
FROM unioned u
JOIN orders o USING (bigcommerce_store, order_id)
