-- core.adobe_commerce.product_sales_over_time
-- Product-level sales with the same equation as sales_over_time, plus cost of
-- goods where Magento recorded a cost. Covers what the admin's Products Ordered
-- and Bestsellers reports show, with money attached.
--
-- Grain: day x store x order x item, top-level items only. A configurable product
-- is one row (the parent, which carries the price and the chosen simple product's
-- SKU), never two. A bundle is reported as the bundle, not its components.
--
-- Order-dated, like sales_over_time: refunds reduce the day the order was placed,
-- because the item's refunded amounts are running totals and no credit memo
-- tables are synced. Same order filter (no new or pending_payment orders), same
-- time zone, same global-currency conversion.
--
-- Cancellations: Magento tracks canceled quantity per item but not canceled
-- money. Ordered amounts are scaled by (qty_ordered - qty_canceled) / qty_ordered,
-- which is exact for a fully canceled order (zero) and for whole-unit
-- cancellations of an evenly priced line.
--
-- Bundles with dynamic pricing: Magento may carry the price on the component rows
-- rather than the bundle row, and those rows are excluded here. If you sell such
-- bundles, assert_product_sales_tie_to_orders will show it.
--
-- Depends on: staging.adobe_commerce.sales_order_item, .sales_order,
--             .store_timezone

WITH orders AS (
    SELECT
        o.adobe_commerce_store,
        o.order_id,
        o.order_number,
        o.store_id,
        o.state,
        o.status,
        o.global_currency_code,
        o.base_to_global_rate,
        DATE(o.created_at, tz.report_timezone) AS date
    FROM {{staging.adobe_commerce.sales_order}} o
    JOIN {{staging.adobe_commerce.store_timezone}} tz USING (adobe_commerce_store)
    WHERE o.state NOT IN ('new', 'pending_payment')
),

items AS (
    SELECT
        i.*,
        -- Share of the line that was not canceled.
        COALESCE(SAFE_DIVIDE(i.qty_ordered - i.qty_canceled, i.qty_ordered), 0) AS kept_share
    FROM {{staging.adobe_commerce.sales_order_item}} i
    WHERE i.is_top_level
),

lines AS (
    SELECT
        o.date,
        i.adobe_commerce_store,
        o.store_id,
        i.order_id,
        o.order_number,
        i.item_id,
        o.state,
        o.status,
        o.global_currency_code,
        o.base_to_global_rate,
        i.product_id,
        i.product_type,
        i.sku,
        i.product_name,
        i.qty_ordered - i.qty_canceled                  AS items_ordered,
        i.qty_refunded                                  AS items_refunded,
        i.qty_ordered - i.qty_canceled - i.qty_refunded AS items_net,
        i.base_row_total * i.kept_share                 AS gross_sales,
        -1 * i.base_discount_amount * i.kept_share      AS discounts,
        -1 * (i.base_amount_refunded - i.base_discount_refunded) AS returns,
        i.base_tax_amount * i.kept_share - i.base_tax_refunded   AS taxes,
        -- NULL, not 0, when the product had no cost: an unknown cost must not read
        -- as a 100% margin.
        i.base_cost * (i.qty_ordered - i.qty_canceled - i.qty_refunded) AS cost_of_goods
    FROM items i
    JOIN orders o USING (adobe_commerce_store, order_id)
)

SELECT
    date,
    adobe_commerce_store,
    store_id,
    order_id,
    order_number,
    item_id,
    state,
    status,
    global_currency_code,
    product_id,
    product_type,
    sku,
    product_name,
    items_ordered,
    items_refunded,
    items_net,
    ROUND(gross_sales * base_to_global_rate, 2)                         AS gross_sales,
    ROUND(discounts * base_to_global_rate, 2)                           AS discounts,
    ROUND(returns * base_to_global_rate, 2)                             AS returns,
    ROUND((gross_sales + discounts + returns) * base_to_global_rate, 2) AS net_sales,
    ROUND(taxes * base_to_global_rate, 2)                               AS taxes,
    ROUND(cost_of_goods * base_to_global_rate, 2)                       AS cost_of_goods,
    ROUND((gross_sales + discounts + returns - cost_of_goods) * base_to_global_rate, 2)
        AS gross_margin
FROM lines
