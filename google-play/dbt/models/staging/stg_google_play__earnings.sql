-- stg_google_play__earnings
-- Thin wrapper over raw `earnings`: Play Console's monthly earnings report, one row
-- per charge, fee, tax or refund line, for every app in the developer account.
-- Casts, renames, parses Google's date text.
--
-- Grain: one row per line of an earnings file (filename x row_number).
--
-- transaction_date is written as text such as "Sep 1, 2026", in Pacific Time per
-- Google's docs. amount_merchant_currency is the line in the currency you are paid
-- in; amount_buyer_currency is the same line in the buyer's currency. Google signs
-- the lines: charges positive, fees and refunds negative. Nothing is re-signed here.

SELECT
    CAST(filename AS STRING)                                AS filename,
    CAST(`row_number` AS INT64)                             AS row_number,
    CAST(description AS STRING)                             AS description,  -- the order ID on order lines
    SAFE.PARSE_DATE('%b %e, %Y', TRIM(CAST(transaction_date AS STRING))) AS transaction_date,
    CAST(transaction_type AS STRING)                        AS transaction_type,
    CAST(refund_type AS STRING)                             AS refund_type,
    CAST(tax_type AS STRING)                                AS tax_type,
    CAST(package_id AS STRING)                              AS package_name,
    CAST(product_title AS STRING)                           AS product_title,
    CAST(product_type AS STRING)                            AS product_type,
    CAST(sku_id AS STRING)                                  AS sku_id,
    CAST(base_plan_or_purchase_option_id AS STRING)         AS base_plan_id,
    UPPER(CAST(buyer_country AS STRING))                    AS buyer_country,
    UPPER(CAST(buyer_currency AS STRING))                   AS buyer_currency,
    CAST(amount_buyer_currency AS NUMERIC)                  AS amount_buyer_currency,
    UPPER(CAST(merchant_currency AS STRING))                AS merchant_currency,
    CAST(amount_merchant_currency AS NUMERIC)               AS amount_merchant_currency,
    CAST(service_fee_percent AS NUMERIC)                    AS service_fee_percent,
    CAST(sales_channel AS STRING)                           AS sales_channel
FROM {{ source('google_play', 'earnings') }}
WHERE TRUE
QUALIFY ROW_NUMBER() OVER (PARTITION BY filename, `row_number` ORDER BY _weld_synced DESC) = 1
