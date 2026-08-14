-- staging.shopify.inventory_item__history
-- Cost changes over time, from Weld's history table for inventory_item. A history
-- table carries the same schema as the source, with one row per observed version -
-- which is what makes point-in-time COGS possible rather than restating every
-- historical order at today's cost.
--
-- Enable it under Data Source -> the Shopify stream -> History tables. Without it
-- this model is empty and costs fall back to the current value.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)             AS inventory_item_id,
    CAST(sku AS STRING)           AS sku,
    CAST(cost AS NUMERIC)         AS cost,
    CAST(updated_at AS TIMESTAMP) AS updated_at
FROM {{raw.shopify.inventory_item__history}}
WHERE sku IS NOT NULL AND TRIM(CAST(sku AS STRING)) != ''
