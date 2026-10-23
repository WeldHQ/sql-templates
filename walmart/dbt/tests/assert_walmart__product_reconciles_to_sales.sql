-- The SKU model must sum to the sales model, day by day, on net sales and units.
-- Both apply the same cancellation and refund rules; if they drift apart, one was
-- changed without the other.
--
-- Returns zero rows when they agree. A cent of tolerance absorbs rounding of the
-- cancelled share of a charge.

WITH sales AS (
    SELECT date, walmart_seller, currency, ship_node_type,
           SUM(net_sales) AS net_sales, SUM(units) AS units
    FROM {{ ref('core_walmart__sales_over_time') }}
    GROUP BY 1, 2, 3, 4
),

product AS (
    SELECT date, walmart_seller, currency, ship_node_type,
           SUM(net_sales) AS net_sales, SUM(units) AS units
    FROM {{ ref('core_walmart__product_sales_over_time') }}
    GROUP BY 1, 2, 3, 4
)

SELECT
    COALESCE(s.date, p.date)                     AS date,
    COALESCE(s.walmart_seller, p.walmart_seller) AS walmart_seller,
    COALESCE(s.currency, p.currency)             AS currency,
    COALESCE(s.ship_node_type, p.ship_node_type) AS ship_node_type,
    s.net_sales AS sales_net_sales,
    p.net_sales AS product_net_sales,
    s.units     AS sales_units,
    p.units     AS product_units
FROM sales s
FULL OUTER JOIN product p
  ON  s.date = p.date
  AND s.walmart_seller = p.walmart_seller
  AND s.currency IS NOT DISTINCT FROM p.currency
  AND s.ship_node_type IS NOT DISTINCT FROM p.ship_node_type
WHERE ABS(COALESCE(s.net_sales, 0) - COALESCE(p.net_sales, 0)) > 0.01
   OR COALESCE(s.units, 0) != COALESCE(p.units, 0)
