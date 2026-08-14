-- stg_shopify__location
-- Physical and virtual locations, used to resolve location_name on the reports.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)                                     AS location_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')                AS location_name,
    UPPER(NULLIF(TRIM(CAST(country_code AS STRING)), '')) AS location_country_code
FROM {{ source('shopify', 'location') }}
