-- staging.shopify.fulfillment
-- Fulfillment events, used to infer which location a POS sale belongs to when
-- the agreement itself carries no location.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(order_id AS INT64)       AS order_id,
    CAST(location_id AS INT64)    AS location_id,
    CAST(created_at AS TIMESTAMP) AS created_at
FROM {{raw.shopify.fulfillment}}
