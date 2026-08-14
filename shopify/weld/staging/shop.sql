-- staging.shopify.shop
-- One row per store. Supplies the base currency and, usefully, the store's own
-- IANA timezone - so the reports localise correctly without hardcoding one.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)                                 AS shop_id,
    CAST(name AS STRING)                              AS shop_name,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), '')) AS currency,
    NULLIF(TRIM(CAST(iana_timezone AS STRING)), '')   AS iana_timezone
FROM {{raw.shopify.shop}}
