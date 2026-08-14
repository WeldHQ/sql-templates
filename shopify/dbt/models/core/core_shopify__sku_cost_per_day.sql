-- shopify_sku_cost_per_day
-- Point-in-time standard cost per SKU, for every day that SKU actually sold.
--
-- Costs change. Valuing a January order at today's cost overstates or understates
-- margin for the whole of history, so this picks the cost that was in effect on
-- the day of the sale: the most recent cost change at or before that day, falling
-- back to the earliest known cost for orders that predate any recorded change.
--
-- Only (day, SKU) pairs that sold are produced, so this stays small rather than
-- materialising a full SKU x calendar grid.
--
-- Depends on: stg_shopify__order, .order_line, .inventory_item,
--             .inventory_item__history, .shop

WITH shop AS (
    SELECT
        shopify_store,
        COALESCE(ANY_VALUE(iana_timezone), 'UTC') AS report_timezone
    FROM {{ ref('stg_shopify__shop') }}
    GROUP BY shopify_store
),

-- Every cost that has ever applied: the history table plus the current value.
cost_grid AS (
    SELECT shopify_store, sku, cost, updated_at AS effective_ts
    FROM {{ ref('stg_shopify__inventory_item__history') }}
    WHERE cost IS NOT NULL

    UNION ALL

    SELECT shopify_store, sku, cost, COALESCE(updated_at, created_at) AS effective_ts
    FROM {{ ref('stg_shopify__inventory_item') }}
    WHERE cost IS NOT NULL
),

-- Only the days each SKU actually sold.
day_skus AS (
    SELECT DISTINCT
        DATE(DATETIME(o.processed_at, s.report_timezone)) AS date,
        ol.shopify_store,
        ol.sku
    FROM {{ ref('stg_shopify__order_line') }} ol
    JOIN {{ ref('stg_shopify__order') }} o USING (shopify_store, order_id)
    JOIN shop s USING (shopify_store)
    WHERE NOT ol.is_gift_card
      AND ol.sku IS NOT NULL
      AND TRIM(ol.sku) != ''
)

SELECT
    ds.date,
    ds.shopify_store,
    ds.sku,
    cg.cost         AS standard_cost,
    cg.effective_ts AS cost_effective_at
FROM day_skus ds
LEFT JOIN cost_grid cg USING (shopify_store, sku)
-- Prefer the newest cost effective on or before the sale day. The ELSE branch
-- keeps the earliest known cost for orders predating any recorded change, so old
-- orders get a cost rather than NULL.
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ds.date, ds.shopify_store, ds.sku
    ORDER BY
        CASE WHEN cg.effective_ts < TIMESTAMP(DATE_ADD(ds.date, INTERVAL 1 DAY)) THEN 0 ELSE 1 END,
        cg.effective_ts DESC
) = 1
