-- staging.amazon_seller.fba_returns
-- Thin wrapper over raw `fba_returns_report`. Casts, renames, signs quantity
-- negative, derives whether the unit came back sellable. No other logic.
--
-- The FBA equivalent of staging.amazon_seller.returns, and deliberately a separate
-- model: this report has no refund amount at all. Amazon tells you a unit came back
-- and what condition it arrived in, and leaves the money in the settlement report.
-- So this is a UNIT-level, not a money-level, source - use it for return rates and
-- recoverable inventory, and take the refunded value from the ledger.
--
-- `detailed_disposition` is the column worth having. SELLABLE means the unit goes
-- back on sale and only the fees were lost. Anything else means the unit is gone
-- and you have eaten the whole COGS - a distinction that typically moves true
-- return cost by a factor of two or three.

SELECT
    'seller_1'                                                  AS amazon_seller,
    CAST(order_id AS STRING)                                    AS amazon_order_id,
    CAST(sku AS STRING)                                         AS sku,
    UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
    CAST(fnsku AS STRING)                                       AS fnsku,
    CAST(product_name AS STRING)                                AS product_name,

    CAST(return_date AS DATE)                                   AS return_date,

    LOWER(CAST(status AS STRING))                               AS return_status,
    LOWER(CAST(detailed_disposition AS STRING))                 AS disposition,
    LOWER(CAST(reason AS STRING))                               AS return_reason,
    CAST(fulfillment_center_id AS STRING)                       AS fulfillment_center_id,

    -- `quantity` is typed as a string in the raw report. Cast via NUMERIC so a
    -- stray decimal does not throw, then to INT64.
    -1 * ABS(CAST(CAST(quantity AS NUMERIC) AS INT64))          AS return_quantity,

    LOWER(CAST(detailed_disposition AS STRING)) = 'sellable'    AS is_resellable,
    'AFN'                                                       AS return_channel
FROM {{raw.amazon_seller_central.fba_returns_report}}
