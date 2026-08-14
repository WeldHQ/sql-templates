-- staging.shopify.order_refund
-- Refund headers. created_at is the date the refund was processed, which is the
-- date returns are attributed to.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)               AS refund_id,
    CAST(order_id AS INT64)         AS order_id,
    CAST(created_at AS TIMESTAMP)   AS refund_created_at
FROM {{raw.shopify.order_refund}}
