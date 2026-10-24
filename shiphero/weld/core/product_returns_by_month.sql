-- core.shiphero.product_returns_by_month
-- Units shipped and units returned per SKU per month, for return rates by product.
-- Grain: month x shiphero_account x account_id x sku.
-- Depends on: staging.shiphero.order, .order_line_item, .return,
--             .return_line_item, .product
--
-- SHIPPED units land on the month the ORDER was placed (order_line_item carries
-- quantity_shipped but no ship date). RETURNED units land on the month the RETURN
-- was created. A return rate over a single month therefore compares returns of
-- earlier orders with this month's shipments; read it over a quarter or longer,
-- or accept the lag.
--
-- Returned units come from return_line_item, which identifies the product by
-- product_id; the SKU is resolved through the product table. A return line whose
-- product is not synced lands under a NULL sku rather than being dropped.
--
-- Received and restocked counts lag: returns are picked up by creation date,
-- so items received after the return's period was synced keep their old counts
-- until it is re-synced.
--
-- account_id is the ShipHero account that owns the order or return. For a 3PL it
-- is the brand, and it is in the grain because two brands can use the same SKU
-- string for different products.
--
-- Built on a month spine per SKU, from the SKU's first activity to the current
-- month, so a SKU with no returns in a month returns zeros.

WITH shipped AS (
    SELECT
        DATE_TRUNC(DATE(COALESCE(o.order_date, o.created_at)), MONTH) AS month,
        li.shiphero_account,
        o.account_id,
        li.sku,
        ANY_VALUE(li.product_name)  AS product_name,
        SUM(li.quantity)            AS units_ordered,
        SUM(li.quantity_shipped)    AS units_shipped
    FROM {{staging.shiphero.order_line_item}} li
    JOIN {{staging.shiphero.order}} o
      ON o.shiphero_account = li.shiphero_account
     AND o.order_id         = li.order_id
    GROUP BY 1, 2, 3, 4
),

returned AS (
    SELECT
        DATE_TRUNC(DATE(r.created_at), MONTH) AS month,
        rl.shiphero_account,
        r.account_id,
        p.sku,
        ANY_VALUE(p.product_name)       AS product_name,
        COUNT(DISTINCT rl.return_id)    AS returns,
        SUM(rl.quantity)                AS units_returned,
        SUM(rl.quantity_received)       AS units_received,
        SUM(rl.quantity_restocked)      AS units_restocked
    FROM {{staging.shiphero.return_line_item}} rl
    JOIN {{staging.shiphero.return}} r
      ON r.shiphero_account = rl.shiphero_account
     AND r.return_id        = rl.return_id
    LEFT JOIN {{staging.shiphero.product}} p
           ON p.shiphero_account = rl.shiphero_account
          AND p.product_id       = rl.product_id
    GROUP BY 1, 2, 3, 4
),

skus AS (
    SELECT shiphero_account, account_id, sku, MIN(month) AS first_month, ANY_VALUE(product_name) AS product_name
    FROM (
        SELECT shiphero_account, account_id, sku, month, product_name FROM shipped
        UNION ALL
        SELECT shiphero_account, account_id, sku, month, product_name FROM returned
    )
    GROUP BY 1, 2, 3
),

spine AS (
    SELECT k.shiphero_account, k.account_id, k.sku, k.product_name, m AS month
    FROM skus k
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(
        k.first_month, DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH
    )) AS m
)

SELECT
    sp.month,
    sp.shiphero_account,
    sp.account_id,
    sp.sku,
    sp.product_name,
    COALESCE(s.units_ordered, 0)    AS units_ordered,
    COALESCE(s.units_shipped, 0)    AS units_shipped,
    COALESCE(r.returns, 0)          AS returns,
    COALESCE(r.units_returned, 0)   AS units_returned,
    COALESCE(r.units_received, 0)   AS units_received,
    COALESCE(r.units_restocked, 0)  AS units_restocked
FROM spine sp
LEFT JOIN shipped s
       ON s.shiphero_account = sp.shiphero_account
      AND s.account_id IS NOT DISTINCT FROM sp.account_id
      AND s.sku IS NOT DISTINCT FROM sp.sku
      AND s.month            = sp.month
LEFT JOIN returned r
       ON r.shiphero_account = sp.shiphero_account
      AND r.account_id IS NOT DISTINCT FROM sp.account_id
      AND r.sku IS NOT DISTINCT FROM sp.sku
      AND r.month            = sp.month
