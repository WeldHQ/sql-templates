-- Gross sales summed over an order's top-level items should equal the order's
-- gross sales (subtotal less canceled subtotal). Magento computes the order
-- subtotal from the same item rows, so a difference points at one of:
--   * a join that fanned out or dropped items,
--   * bundles with dynamic pricing, whose money sits on component rows that the
--     product model excludes,
--   * partial cancellations of unevenly priced lines (see the product model).
--
-- Returns the orders that disagree by more than a cent per item.

WITH orders AS (
    SELECT adobe_commerce_store, order_id, gross_sales
    FROM {{ ref('core_adobe_commerce__sales_over_time') }}
),

products AS (
    SELECT adobe_commerce_store, order_id, SUM(gross_sales) AS gross_sales, COUNT(*) AS n
    FROM {{ ref('core_adobe_commerce__product_sales_over_time') }}
    GROUP BY 1, 2
)

SELECT
    o.adobe_commerce_store,
    o.order_id,
    o.gross_sales AS order_gross_sales,
    p.gross_sales AS product_gross_sales
FROM orders o
LEFT JOIN products p USING (adobe_commerce_store, order_id)
WHERE ABS(o.gross_sales - COALESCE(p.gross_sales, 0)) > 0.01 * GREATEST(COALESCE(p.n, 0), 1)
