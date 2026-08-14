-- shopify_sales_by_product - recreates Shopify's "Total sales by product"
-- Grain: product x variant (SKU) x day, on the ORDER date. Currency: shop money.
-- Depends on: staging.shopify.order, .order_line, .product
--
-- SCOPE: net of discounts, NOT net of returns. Does not reconcile to
-- shopify_sales_over_time - returns stay on the original order date. Right for
-- ranking top sellers, wrong for SKU revenue that has to tie out.

WITH orders AS (
    SELECT shopify_store, order_id, DATE(processed_at) AS date
    FROM {{staging.shopify.order}}
)

SELECT
    o.date,
    l.shopify_store,
    l.product_id,
    -- Canonical product attributes beat the order_line snapshot, which was taken
    -- at purchase time and goes stale if a product is renamed.
    COALESCE(p.product_title, l.product_title) AS product_title,
    p.product_type,
    COALESCE(p.vendor, l.vendor)               AS vendor,
    l.variant_id,
    l.variant_title,
    l.sku,
    SUM(l.quantity)                            AS units,
    COUNT(DISTINCT o.order_id)                 AS orders,
    ROUND(SUM(l.gross_sales), 2)               AS gross_sales,
    ROUND(SUM(l.discounts), 2)                 AS discounts,
    ROUND(SUM(l.gross_sales - l.discounts), 2) AS net_sales
FROM {{staging.shopify.order_line}} l
-- shopify_store in every join key: order IDs are only unique within a store.
JOIN orders o USING (shopify_store, order_id)
LEFT JOIN {{staging.shopify.product}} p USING (shopify_store, product_id)
-- Gift cards are deferred revenue, not product revenue. staging.shopify.order_line
-- keeps them, so exclude them here.
WHERE NOT l.is_gift_card
-- Ordinals, not names: product_title and vendor exist on both joined tables, so
-- a bare column name here would be ambiguous.
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY o.date, net_sales DESC
