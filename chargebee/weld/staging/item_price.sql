-- staging.chargebee.item_price
-- Thin wrapper over raw `item_price` (Product Catalog 2.0). One row per item
-- price. Used to look up the item behind a plan or add-on line.
-- Sites still on the legacy catalog have no rows here; core handles that.

SELECT
    CAST(id AS STRING)                                          AS item_price_id,
    CAST(item_id AS STRING)                                     AS item_id,
    CAST(item_family_id AS STRING)                              AS item_family_id,
    CAST(name AS STRING)                                        AS item_price_name,
    LOWER(CAST(item_type AS STRING))                            AS item_type,
    LOWER(CAST(status AS STRING))                               AS status,
    LOWER(CAST(pricing_model AS STRING))                        AS pricing_model,
    UPPER(CAST(currency_code AS STRING))                        AS currency,
    CAST(period AS INT64)                                       AS billing_period,
    LOWER(CAST(period_unit AS STRING))                          AS billing_period_unit
FROM {{raw.chargebee.item_price}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
