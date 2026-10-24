-- stg_grin__product
-- Thin wrapper over raw `product`: the products available for seeding, with the
-- unit cost, retail price and shipping cost entered in Grin (account currency).
--
-- Current values only: a cost changed today revalues every past seeding order.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                              AS grin_account,
    CAST(id AS STRING)                       AS product_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')   AS product_name,
    NULLIF(CAST(sku AS STRING), '')          AS sku,
    CAST(cost AS NUMERIC)                    AS cost,
    CAST(price AS NUMERIC)                   AS price,
    CAST(shipping_cost AS NUMERIC)           AS shipping_cost
FROM {{ source('grin', 'product') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
