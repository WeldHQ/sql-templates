-- staging.shiphero.product
-- Thin wrapper over raw `product`. One row per product (SKU) per ShipHero account.

SELECT
    'account_1'                              AS shiphero_account,
    CAST(id AS STRING)                       AS product_id,
    CAST(account_id AS STRING)               AS account_id,
    NULLIF(TRIM(CAST(sku AS STRING)), '')    AS sku,
    NULLIF(TRIM(CAST(name AS STRING)), '')   AS product_name,
    CAST(kit AS BOOL)                        AS is_kit
FROM {{raw.shiphero.product}}
