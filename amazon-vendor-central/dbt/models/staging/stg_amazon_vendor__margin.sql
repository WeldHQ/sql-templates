-- stg_amazon_vendor__margin
-- Thin wrapper over raw `vendor_net_pure_product_margin_report`. Casts, renames,
-- de-duplicates. No other logic.
--
-- READ THE DEFINITION BEFORE USING THIS COLUMN. Net Pure Product Margin is AMAZON'S
-- margin on selling your product, not yours:
--
--     (Amazon's retail revenue - what Amazon paid you - vendor-funded co-op) / revenue
--
-- Your own margin is shipped_cogs minus your cost of goods, and Amazon has no idea
-- what that is. Every model here that mentions margin means Amazon's, and says so.
--
-- It is worth tracking anyway, because it is the number your Vendor Manager is
-- measured on. An ASIN where Amazon's margin is thin is an ASIN where you will be
-- asked for better terms, or which quietly stops being promoted. Watching NPPM fall
-- is advance notice of a conversation about cost price.

SELECT
    'vendor_1'                                                  AS amazon_vendor,
    marketplace,
    date,
    asin,
    net_pure_product_margin
FROM (
    SELECT
        UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,
        CAST(start_date AS DATE)                                    AS date,
        UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
        CAST(net_pure_product_margin AS NUMERIC)                    AS net_pure_product_margin,
        ROW_NUMBER() OVER (
            PARTITION BY marketplace_id, CAST(start_date AS DATE), asin
            ORDER BY _weld_synced DESC
        ) AS generation_rank
    FROM {{ source('amazon_vendor_central', 'vendor_net_pure_product_margin_report') }}
)
WHERE generation_rank = 1
