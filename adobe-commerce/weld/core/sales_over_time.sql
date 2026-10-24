-- core.adobe_commerce.sales_over_time
-- Recreates the Adobe Commerce admin "Orders" sales report (Reports > Sales >
-- Orders: orders, sales items, sales total, invoiced, refunded, sales tax, sales
-- shipping, sales discount, canceled) and adds a sales equation on top.
--
-- Grain: day x store x order. Aggregate to day, store view or status in BI.
--
-- ORDER-DATED, NOT EVENT-BASED. Read this before using `returns`. Only sales_order
-- is synced, and its refunded and canceled amounts are running totals on the order
-- row. Without the credit memo tables there is no refund date, so a refund made in
-- March reduces the January order it belongs to, and past days change every time
-- an old order is refunded. This is also how the admin report behaves when run by
-- order creation date. Shopify-style "returns on the return date" needs
-- sales_creditmemo, which is not synced.
--
-- Matches the admin report's rules:
--   * Orders in state new or pending_payment are left out, as the report does.
--     Canceled orders stay in, with their canceled amounts subtracted, so a fully
--     canceled order counts as an order with zero sales.
--   * Money is base currency x base_to_global_rate, i.e. the global currency.
--     For a single-website store the rate is 1 and nothing changes.
--   * The date is created_at converted to the time zone in
--     staging/store_timezone.sql. Set it, or days will not match.
--
-- The sales equation (discounts and returns negative, so net = gross + discounts
-- + returns is plain addition):
--   gross_sales  subtotal ordered, net of cancellations, before discount and tax
--   discounts    discounts given, net of cancellations
--   returns      refunded amount excluding refunded tax and shipping; includes
--                credit memo adjustments (adjustment refunds and fees)
--   shipping, taxes  charged, net of cancellations and refunds
--   total_sales  net_sales + shipping + taxes
-- With prices entered including tax, Magento books a small "discount tax
-- compensation" into the grand total that is in none of these columns, so
-- total_sales can differ from sales_total by that amount.
--
-- Depends on: staging.adobe_commerce.sales_order, .sales_order_item,
--             .store_timezone

WITH orders AS (
    SELECT
        o.*,
        DATE(o.created_at, tz.report_timezone) AS date
    FROM {{staging.adobe_commerce.sales_order}} o
    JOIN {{staging.adobe_commerce.store_timezone}} tz USING (adobe_commerce_store)
    WHERE o.state NOT IN ('new', 'pending_payment')
),

-- "Sales Items" in the admin report: quantity ordered less quantity canceled, on
-- top-level items only so a configurable product is not counted twice (once as
-- the parent row, once as the child). One row per order, so the join cannot fan out.
order_items AS (
    SELECT
        adobe_commerce_store,
        order_id,
        SUM(qty_ordered - qty_canceled) AS items_ordered,
        SUM(qty_invoiced)               AS items_invoiced,
        SUM(qty_refunded)               AS items_refunded
    FROM {{staging.adobe_commerce.sales_order_item}}
    WHERE is_top_level
    GROUP BY adobe_commerce_store, order_id
),

amounts AS (
    SELECT
        o.date,
        o.adobe_commerce_store,
        o.store_id,
        o.order_id,
        o.order_number,
        o.state,
        o.status,
        o.state = 'canceled' AS is_canceled,
        o.customer_id,
        o.is_guest,
        o.customer_group_id,
        o.coupon_code,
        o.global_currency_code,
        o.base_currency_code,
        o.base_to_global_rate,
        COALESCE(oi.items_ordered, 0)  AS items_ordered,
        COALESCE(oi.items_invoiced, 0) AS items_invoiced,
        COALESCE(oi.items_refunded, 0) AS items_refunded,

        -- Sales equation, still in base currency.
        o.base_subtotal - o.base_subtotal_canceled                AS gross_sales,
        -1 * (o.base_discount_amount - o.base_discount_canceled)   AS discounts,
        -1 * (o.base_total_refunded - o.base_tax_refunded - o.base_shipping_refunded)
                                                                  AS returns,
        -1 * (o.base_adjustment_positive - o.base_adjustment_negative)
                                                                  AS return_adjustments,
        o.base_shipping_amount - o.base_shipping_canceled - o.base_shipping_refunded
                                                                  AS shipping,
        o.base_tax_amount - o.base_tax_canceled - o.base_tax_refunded
                                                                  AS taxes,

        -- The admin report's own columns, same definitions as Magento's report
        -- aggregation.
        o.base_grand_total - o.base_total_canceled                AS sales_total,
        o.base_total_invoiced                                     AS invoiced,
        o.base_total_paid                                         AS paid,
        o.base_total_refunded                                     AS refunded,
        o.base_total_canceled                                     AS canceled,
        o.base_tax_amount - o.base_tax_canceled                   AS sales_tax,
        o.base_shipping_amount - o.base_shipping_canceled         AS sales_shipping,
        o.base_discount_amount - o.base_discount_canceled         AS sales_discount,
        o.base_total_invoiced - o.base_tax_invoiced - o.base_shipping_invoiced
          - (o.base_total_refunded - o.base_tax_refunded - o.base_shipping_refunded)
                                                                  AS revenue,
        o.base_total_paid - o.base_total_refunded - o.base_tax_invoiced
          - o.base_shipping_invoiced - o.base_total_invoiced_cost AS profit
    FROM orders o
    LEFT JOIN order_items oi USING (adobe_commerce_store, order_id)
)

SELECT
    date,
    adobe_commerce_store,
    store_id,
    order_id,
    order_number,
    state,
    status,
    is_canceled,
    customer_id,
    is_guest,
    customer_group_id,
    coupon_code,
    global_currency_code,
    base_currency_code,
    base_to_global_rate,

    1 AS orders,
    items_ordered,
    items_invoiced,
    items_refunded,

    ROUND(gross_sales * base_to_global_rate, 2)        AS gross_sales,
    ROUND(discounts * base_to_global_rate, 2)          AS discounts,
    ROUND(returns * base_to_global_rate, 2)            AS returns,
    ROUND(return_adjustments * base_to_global_rate, 2) AS return_adjustments,
    ROUND((gross_sales + discounts + returns) * base_to_global_rate, 2) AS net_sales,
    ROUND(shipping * base_to_global_rate, 2)           AS shipping,
    ROUND(taxes * base_to_global_rate, 2)              AS taxes,
    ROUND((gross_sales + discounts + returns + shipping + taxes) * base_to_global_rate, 2)
        AS total_sales,

    ROUND(sales_total * base_to_global_rate, 2)    AS sales_total,
    ROUND(invoiced * base_to_global_rate, 2)       AS invoiced,
    ROUND(paid * base_to_global_rate, 2)           AS paid,
    ROUND(refunded * base_to_global_rate, 2)       AS refunded,
    ROUND(canceled * base_to_global_rate, 2)       AS canceled,
    ROUND(sales_tax * base_to_global_rate, 2)      AS sales_tax,
    ROUND(sales_shipping * base_to_global_rate, 2) AS sales_shipping,
    ROUND(sales_discount * base_to_global_rate, 2) AS sales_discount,
    ROUND(revenue * base_to_global_rate, 2)        AS revenue,
    ROUND(profit * base_to_global_rate, 2)         AS profit
FROM amounts
