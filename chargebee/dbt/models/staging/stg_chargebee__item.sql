-- stg_chargebee__item
-- Thin wrapper over raw `item` (Product Catalog 2.0). One row per item.
-- `included_in_mrr` is Chargebee's own switch for whether an item counts towards
-- MRR; core respects it.

SELECT
    CAST(id AS STRING)                                          AS item_id,
    CAST(name AS STRING)                                        AS item_name,
    LOWER(CAST(type AS STRING))                                 AS item_type,
    LOWER(CAST(status AS STRING))                               AS status,
    CAST(included_in_mrr AS BOOL)                               AS included_in_mrr,
    COALESCE(CAST(metered AS BOOL), FALSE)                      AS is_metered
FROM {{ source('chargebee', 'item') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
