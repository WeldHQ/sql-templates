-- On SALE rows the product model must sum to the order model, order by order:
-- gross from the line totals, and discounts from line discounts plus the
-- allocated order-level remainder.
--
-- Usual causes of a failure: an order whose line totals do not add up to
-- subtotal_ex_tax (check bundled products), or an order with no synced lines.
-- RETURN rows are excluded on purpose: product returns are estimated per unit and
-- exclude refunded shipping, so they are not expected to tie.

WITH order_level AS (
    SELECT bigcommerce_store, order_id, SUM(gross_sales) AS gross_sales, SUM(net_sales) AS net_sales
    FROM {{ ref('core_bigcommerce__sales_over_time') }}
    WHERE row_type = 'SALE'
    GROUP BY 1, 2
),

product_level AS (
    SELECT bigcommerce_store, order_id, SUM(gross_sales) AS gross_sales, SUM(net_sales) AS net_sales
    FROM {{ ref('core_bigcommerce__product_sales_over_time') }}
    WHERE row_type = 'SALE'
    GROUP BY 1, 2
)

SELECT
    COALESCE(o.bigcommerce_store, p.bigcommerce_store) AS bigcommerce_store,
    COALESCE(o.order_id, p.order_id)                   AS order_id,
    o.gross_sales AS order_level_gross_sales,
    p.gross_sales AS product_level_gross_sales,
    o.net_sales   AS order_level_net_sales,
    p.net_sales   AS product_level_net_sales
FROM order_level o
FULL OUTER JOIN product_level p USING (bigcommerce_store, order_id)
WHERE ABS(COALESCE(o.gross_sales, 0) - COALESCE(p.gross_sales, 0)) > 0.01
   OR ABS(COALESCE(o.net_sales, 0)   - COALESCE(p.net_sales, 0))   > 0.01
