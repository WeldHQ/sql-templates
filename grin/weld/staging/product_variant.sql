-- staging.grin.product_variant
-- Thin wrapper over raw `product_variant`: variant-level cost, price and
-- shipping cost. Core prefers these over the product's own values when a selection
-- names a variant.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                              AS grin_account,
    CAST(id AS STRING)                       AS variant_id,
    CAST(product_id AS STRING)               AS product_id,
    NULLIF(CAST(sku AS STRING), '')          AS sku,
    CAST(cost AS NUMERIC)                    AS cost,
    CAST(price AS NUMERIC)                   AS price,
    CAST(shipping_cost AS NUMERIC)           AS shipping_cost
FROM {{raw.grin.product_variant}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
