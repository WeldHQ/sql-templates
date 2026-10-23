-- What Amazon pays you should not exceed what Amazon charges the customer.
--
-- shipped_cogs is your wholesale price; shipped_revenue is Amazon's retail price. On
-- a promotion or a price match Amazon will occasionally sell below cost, so this is
-- not an invariant on any single day - but persistently, across a month, it is.
--
-- A failure at month grain almost always means the two columns were mapped to the
-- wrong source fields, which is easy to do: the report calls your revenue
-- "shippedCogs", and the obvious reading of "revenue" is the wrong one. When they are
-- swapped, every margin number inverts and the model reports Amazon's business
-- instead of yours.
--
-- Closed months only; the current one is still restating.

SELECT
    DATE_TRUNC(date, MONTH) AS month,
    amazon_vendor,
    marketplace,
    distributor_view,
    selling_program,
    ROUND(SUM(shipped_cogs), 2)     AS shipped_cogs,
    ROUND(SUM(shipped_revenue), 2)  AS shipped_revenue,
    ROUND(SUM(shipped_cogs) - SUM(shipped_revenue), 2) AS diff
FROM {{ ref('core_amazon_vendor__sales_over_time') }}
WHERE date < DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND shipped_revenue IS NOT NULL
GROUP BY 1, 2, 3, 4, 5
HAVING SUM(shipped_cogs) > SUM(shipped_revenue)
