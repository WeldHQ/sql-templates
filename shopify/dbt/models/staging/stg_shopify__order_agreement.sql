-- stg_shopify__order_agreement
-- The financial event log, one row per change to an order's value.
-- 'voided' agreements were cancelled before they ever represented money.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS STRING)                          AS order_agreement_id,
    CAST(order_id AS INT64)                     AS order_id,
    CAST(happened_at AS TIMESTAMP)              AS happened_at,
    LOWER(CAST(app_handle AS STRING))           AS app_handle,
    UPPER(COALESCE(CAST(reason AS STRING), '')) AS reason
FROM {{ source('shopify', 'order_agreement') }}
WHERE LOWER(COALESCE(CAST(reason AS STRING), '')) != 'voided'
