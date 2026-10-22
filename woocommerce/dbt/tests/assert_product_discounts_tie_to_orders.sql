-- sales_over_time takes its coupon discounts from the same product lines that
-- product_sales_over_time reports, with the same status and date rules, so the
-- two must agree per store and day. A difference means a join fanned out or the
-- two models stopped applying the same filters.
--
-- Returns the days that disagree by more than a cent per order row, which is the
-- most per-row rounding can explain.

WITH orders AS (
    SELECT date, woocommerce_store, SUM(discounts) AS discounts, COUNT(*) AS n
    FROM {{ ref('core_woocommerce__sales_over_time') }}
    GROUP BY 1, 2
),

products AS (
    SELECT date, woocommerce_store, SUM(discounts) AS discounts
    FROM {{ ref('core_woocommerce__product_sales_over_time') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(o.date, p.date)                           AS date,
    COALESCE(o.woocommerce_store, p.woocommerce_store) AS woocommerce_store,
    o.discounts AS order_discounts,
    p.discounts AS product_discounts
FROM orders o
FULL OUTER JOIN products p USING (date, woocommerce_store)
WHERE ABS(COALESCE(o.discounts, 0) - COALESCE(p.discounts, 0)) > 0.01 * GREATEST(COALESCE(o.n, 0), 1)
