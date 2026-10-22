-- core_salesforce_commerce_cloud__sales_over_time
-- The sales equation per order, on the day the order was placed.
--
-- Grain: day x instance x site x order. Currency: the order's own (`currency`).
-- Timezone: staging.salesforce_commerce_cloud.settings.report_timezone.
--
-- Depends on: staging.salesforce_commerce_cloud.order, .order_product_item, .settings
--
-- THERE ARE NO RETURN ROWS, because the connector syncs no returns, refunds or
-- payment transactions: the order record is all there is. Cancelling an order in
-- Commerce Cloud changes its status, and this model then drops it, so a cancelled
-- order disappears from the day it was placed rather than appearing as a reversal
-- on the day it was cancelled. History restates. If you need returns, they live in
-- your order management system, not in this connector.
--
-- WHICH ORDERS COUNT. new, open and completed. Dropped: created (not yet placed,
-- typically payment still in progress), failed, cancelled and replaced (an order
-- edited by replacement; its successor is a new order, so keeping both would count
-- the sale twice).
--
-- TAX BASIS. Gross-taxation sites price tax-inclusive, net-taxation sites do not.
-- The equation below is in the site's own basis, as Business Manager shows it, and
-- the *_ex_tax columns are comparable across both.

WITH settings AS (
    SELECT sfcc_instance, report_timezone
    FROM {{ ref('stg_salesforce_commerce_cloud__settings') }}
),

-- Pre-aggregated to one row per order, so joining lines cannot fan out the header
-- money.
items AS (
    SELECT
        sfcc_instance,
        order_no,
        SUM(price)                                          AS gross_sales,
        SUM(price_after_item_discount - price)              AS item_discounts,
        SUM(quantity)                                       AS quantity,
        COUNT(*)                                            AS product_lines
    FROM {{ ref('stg_salesforce_commerce_cloud__order_product_item') }}
    GROUP BY sfcc_instance, order_no
)

SELECT
    DATE(COALESCE(o.placed_at, o.created_at), s.report_timezone)   AS date,
    o.sfcc_instance,
    o.site_id,
    o.order_no,
    o.currency,
    o.taxation,
    o.taxation = 'gross'                                            AS prices_include_tax,
    o.status,
    o.payment_status,
    o.shipping_status,
    o.customer_id,
    o.is_guest,
    o.billing_country_code,
    o.customer_locale,

    -- The sales equation, in the site's tax basis. Discounts are negative.
    i.gross_sales,
    i.item_discounts,
    o.product_total - o.product_sub_total                           AS order_discounts,
    o.product_total                                                 AS net_sales,
    o.shipping_total                                                AS shipping,
    o.tax_total                                                     AS taxes,
    o.order_total                                                   AS total_sales,

    -- Tax-exclusive, comparable across gross and net sites.
    o.product_total
        - IF(o.taxation = 'gross', COALESCE(o.merchandise_tax, 0), 0) AS net_sales_ex_tax,
    o.shipping_total
        - IF(o.taxation = 'gross', COALESCE(o.shipping_tax, 0), 0)    AS shipping_ex_tax,
    -- order_total contains tax under both bases: inside the prices on a gross
    -- site, added on top on a net site.
    o.order_total - COALESCE(o.tax_total, 0)                        AS total_sales_ex_tax,

    -- Should be zero. product_sub_total is Commerce Cloud's own figure; the right
    -- side is rebuilt from the parsed lines. A non-zero value means product_items
    -- did not parse for this order, see staging.order_product_item.
    o.product_sub_total
        - (COALESCE(i.gross_sales, 0) + COALESCE(i.item_discounts, 0)) AS unparsed_line_amount,

    i.quantity,
    i.product_lines,
    1                                                               AS orders
FROM {{ ref('stg_salesforce_commerce_cloud__order') }} o
JOIN settings s USING (sfcc_instance)
LEFT JOIN items i USING (sfcc_instance, order_no)
WHERE o.status IN ('new', 'open', 'completed')
