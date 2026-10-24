-- stg_traede__variant
-- Thin wrapper over raw `variant`. One row per variant (SKU).
--
-- COST IS CURRENT STATE. `cost_price` and `landed_cost` are what the variant
-- costs today; the stream carries no cost history, so a sale from last season is
-- valued at this season's cost. Traede does not document the currency of these
-- two fields; core treats them as the account's base currency (see
-- core.traede.product_sales).

SELECT
    'account_1'                                AS traede_account,
    CAST(id AS STRING)                         AS variant_id,
    NULLIF(TRIM(CAST(sku AS STRING)), '')      AS sku,
    NULLIF(TRIM(CAST(ean AS STRING)), '')      AS ean,
    CAST(cost_price AS NUMERIC)                AS unit_cost_price,
    CAST(landed_cost AS NUMERIC)               AS unit_landed_cost
FROM {{ source('traede', 'variant') }}
