-- staging.shopify.order_line_refund
-- Per-line refund detail. restock_type is what distinguishes a cancellation from
-- a genuine return from a refund-without-restock.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

-- order_id is deliberately not selected: it is reached through order_refund,
-- which is how Shopify's own schema links these.
SELECT
    'store_1'                     AS shopify_store,
    CAST(refund_id AS INT64)                AS refund_id,
    CAST(order_line_id AS INT64)            AS order_line_id,
    CAST(location_id AS INT64)              AS location_id,
    COALESCE(CAST(quantity AS INT64), 0)    AS quantity,
    LOWER(CAST(restock_type AS STRING))     AS restock_type
FROM {{raw.shopify.order_line_refund}}
