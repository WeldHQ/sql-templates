-- staging.amazon_seller.listings
-- Thin wrapper over raw `merchant_listings_report`. Casts, renames, resolves the
-- ASIN. The SKU dimension table for this library.
--
-- WHY THIS EXISTS. Amazon's reports disagree about which identifier is the key.
-- Order and settlement data are keyed on SKU, traffic data on ASIN, and FBA reports
-- on FNSKU. Nothing joins to anything until one table maps between them, and this
-- is it - plus the listing attributes (price, status, fulfilment channel) that make
-- an ASIN report readable.
--
-- asin_1 is the ASIN the listing actually points at. asin_2 and asin_3 exist for
-- historical multi-ASIN listings and are almost always empty; the COALESCE keeps
-- those rare rows joinable instead of NULL.
--
-- One row per SKU per marketplace. If yours is not unique on that, the report was
-- synced across marketplaces into one table without marketplace_id populated - add
-- it to the grain here rather than de-duplicating downstream.

SELECT
    'seller_1'                                                  AS amazon_seller,
    UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
    CAST(seller_sku AS STRING)                                  AS sku,
    UPPER(NULLIF(TRIM(CAST(COALESCE(asin_1, asin_2, asin_3) AS STRING)), '')) AS asin,
    CAST(listing_id AS STRING)                                  AS listing_id,
    CAST(item_name AS STRING)                                   AS product_name,
    LOWER(CAST(status AS STRING))                               AS listing_status,
    LOWER(CAST(item_condition AS STRING))                       AS item_condition,
    LOWER(CAST(fulfillment_channel AS STRING))                  AS fulfillment_channel,
    CAST(merchant_shipping_group AS STRING)                     AS shipping_group,
    CAST(price AS NUMERIC)                                      AS list_price,
    CAST(quantity AS INT64)                                     AS listed_quantity,
    CAST(pending_quantity AS INT64)                             AS pending_quantity,
    CAST(open_date AS TIMESTAMP)                                AS listing_opened_at,
    LOWER(CAST(status AS STRING)) = 'active'                     AS is_active
FROM {{raw.amazon_seller_central.merchant_listings_report}}
