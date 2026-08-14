-- stg_shopify__order
-- Thin wrapper over raw `order`. Casts, renames, drops test orders. No other logic.
--
-- Single store. To add another, UNION ALL a second block below pointing at that
-- store's connector with a different shopify_store label. Keep it in staging so
-- the core models never have to know how many stores there are.

SELECT
    'store_1'                     AS shopify_store,
    CAST(id AS INT64)                       AS order_id,
    CAST(name AS STRING)                    AS order_name,
    CAST(customer_id AS INT64)              AS customer_id,
    CAST(location_id AS INT64)              AS location_id,
    LOWER(CAST(source_name AS STRING))      AS source_name,
    CAST(processed_at AS TIMESTAMP)         AS processed_at,
    CAST(created_at AS TIMESTAMP)           AS created_at,
    CAST(cancelled_at AS TIMESTAMP)         AS cancelled_at,
    CAST(closed_at AS TIMESTAMP)            AS closed_at,

    -- COALESCE to '' so downstream NOT IN (...) filters keep NULL-status orders
    -- rather than silently dropping them.
    LOWER(COALESCE(CAST(financial_status AS STRING), ''))   AS financial_status,
    LOWER(CAST(fulfillment_status AS STRING))               AS fulfillment_status,

    -- The order's own currency, preferred over the shop's CURRENT currency.
    -- Stores that changed base currency, or imported history from another
    -- platform, hold orders denominated in something else; defaulting to today's
    -- shop currency would mislabel them by the full FX factor.
    UPPER(NULLIF(TRIM(CAST(current_total_price_set_shop_money_currency_code AS STRING)), '')) AS order_shop_currency,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))                                        AS currency,
    UPPER(NULLIF(TRIM(CAST(current_total_price_set_presentment_money_currency_code AS STRING)), '')) AS order_presentment_currency,
    UPPER(NULLIF(TRIM(CAST(presentment_currency AS STRING)), ''))                            AS presentment_currency,

    UPPER(NULLIF(TRIM(CAST(shipping_address_country_code AS STRING)), '')) AS shipping_country_code,
    UPPER(NULLIF(TRIM(CAST(billing_address_country_code AS STRING)), ''))  AS billing_country_code
FROM {{ source('shopify', 'order') }}
WHERE COALESCE(test, FALSE) = FALSE
