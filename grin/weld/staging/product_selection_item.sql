-- staging.grin.product_selection_item
-- Thin wrapper over raw `product_selection_item`: the products a creator picked
-- in a product selection, one row per item. Grin records no quantity, so each row
-- is one unit.
--
-- Single Grin account; see staging.grin.campaign.

SELECT
    'account_1'                                  AS grin_account,
    CAST(id AS STRING)                           AS item_id,
    CAST(product_selection_id AS STRING)         AS product_selection_id,
    CAST(contact_id AS STRING)                   AS contact_id,
    CAST(product_id AS STRING)                   AS product_id,
    NULLIF(CAST(variant_id AS STRING), '')       AS variant_id
FROM {{raw.grin.product_selection_item}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) = 1
