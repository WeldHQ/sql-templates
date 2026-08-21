-- stg_amazon_seller__orders
-- Thin wrapper over raw `orders_by_last_updated_date_report`. Casts, renames,
-- fixes the sign on discounts. No other logic.
--
-- WHY THIS TABLE AND NOT `orders` + `orderitems`. The API pair gives you a header
-- table and a line table, both of which are CURRENT STATE - they describe what the
-- order looks like right now. This report is one row per order line with every
-- money column already on it, is keyed on `last_updated_date` so it syncs
-- incrementally, and carries no PII, so it is not restricted. The API pair is still
-- the right choice if you need buyer or address detail; see the README.
--
-- Single marketplace region. To add another, UNION ALL a second block below
-- pointing at that connector with a different amazon_seller label. Keep it in
-- staging so the core models never have to know how many accounts there are.

{{ config(materialized='table') }}

SELECT
    'seller_1'                                              AS amazon_seller,
    UPPER(NULLIF(TRIM(CAST(sales_channel AS STRING)), ''))  AS marketplace,

    CAST(amazon_order_id AS STRING)                         AS amazon_order_id,
    CAST(merchant_order_id AS STRING)                       AS merchant_order_id,
    CAST(sku AS STRING)                                     AS sku,
    UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))           AS asin,
    CAST(product_name AS STRING)                            AS product_name,

    CAST(purchase_date AS DATE)                             AS purchase_date,
    CAST(last_updated_date AS DATE)                         AS last_updated_date,

    LOWER(CAST(order_status AS STRING))                     AS order_status,
    LOWER(CAST(item_status AS STRING))                      AS item_status,
    LOWER(CAST(fulfillment_channel AS STRING))              AS fulfillment_channel,
    LOWER(CAST(order_channel AS STRING))                    AS order_channel,
    LOWER(CAST(ship_service_level AS STRING))               AS ship_service_level,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))       AS currency,

    CAST(quantity AS INT64)                                 AS quantity,

    -- Money, all in the order's own currency. Amazon reports item_price INCLUSIVE
    -- of nothing else: it is price x quantity for the line, tax excluded and held
    -- separately in item_tax.
    CAST(item_price AS NUMERIC)                             AS item_price,
    CAST(item_tax AS NUMERIC)                               AS item_tax,
    CAST(shipping_price AS NUMERIC)                         AS shipping_price,
    CAST(shipping_tax AS NUMERIC)                           AS shipping_tax,
    CAST(gift_wrap_price AS NUMERIC)                        AS gift_wrap_price,
    CAST(gift_wrap_tax AS NUMERIC)                          AS gift_wrap_tax,

    -- Amazon reports both promotion discounts as POSITIVE magnitudes. Every other
    -- model in this library follows the convention that a discount is negative, so
    -- net = gross + discounts is plain addition. Flip the sign once, here, and no
    -- downstream model has to remember which way round Amazon stores it.
    -1 * ABS(CAST(item_promotion_discount AS NUMERIC))      AS item_promotion_discount,
    -1 * ABS(CAST(ship_promotion_discount AS NUMERIC))      AS ship_promotion_discount,

    -- VAT-exclusive variants are populated in EU/UK marketplaces only. Where they
    -- are NULL the *_price columns are already net of VAT.
    CAST(vat_exclusive_item_price AS NUMERIC)               AS vat_exclusive_item_price,
    CAST(vat_exclusive_shipping_price AS NUMERIC)           AS vat_exclusive_shipping_price,
    CAST(vat_exclusive_giftwrap_price AS NUMERIC)           AS vat_exclusive_giftwrap_price,

    CAST(promotion_ids AS STRING)                           AS promotion_ids,
    UPPER(NULLIF(TRIM(CAST(ship_country AS STRING)), ''))   AS ship_country,
    CAST(ship_state AS STRING)                              AS ship_state,
    CAST(ship_city AS STRING)                               AS ship_city,

    COALESCE(CAST(is_business_order AS BOOL), FALSE)        AS is_business_order,

    -- Cancelled lines are KEPT, flagged rather than filtered. Amazon's own Business
    -- Reports net cancellations out of ordered_product_sales on the ORIGINAL order
    -- date, so a model that drops the rows cannot reproduce that behaviour, and a
    -- model that keeps them without a flag cannot exclude them either.
    LOWER(CAST(item_status AS STRING)) = 'cancelled'        AS is_cancelled
FROM {{ source('amazon_seller_central', 'orders_by_last_updated_date_report') }}
