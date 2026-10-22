-- stg_toast__selection
-- Thin wrapper over raw `order_check_selection`. One row per item sold on a check.
--
-- Toast's price fields:
--   pre_discount_price  the selection's price before discounts
--   price               after discounts, including modifiers and quantity
--   tax                 tax on the selection
-- Gift card sales and other deferred revenue have deferred = true; they are kept
-- here and separated in core.

SELECT
    CAST(guid AS STRING)                    AS selection_id,
    CAST(order_check_guid AS STRING)        AS check_id,
    CAST(order_guid AS STRING)              AS order_id,
    CAST(restaurant_guid AS STRING)         AS restaurant_id,
    CAST(item_guid AS STRING)               AS menu_item_id,
    CAST(item_group_guid AS STRING)         AS menu_group_id,
    CAST(display_name AS STRING)            AS item_name,
    CAST(sales_category_guid AS STRING)     AS sales_category_id,
    UPPER(CAST(selection_type AS STRING))   AS selection_type,
    CAST(quantity AS FLOAT64)               AS quantity,
    CAST(pre_discount_price AS FLOAT64)     AS pre_discount_price,
    CAST(price AS FLOAT64)                  AS price,
    CAST(tax AS FLOAT64)                    AS tax,
    COALESCE(CAST(refund_details_refund_amount AS FLOAT64), 0) AS refund_amount,
    COALESCE(voided, FALSE)                 AS is_voided,
    COALESCE(deferred, FALSE)               AS is_deferred
FROM {{ source('toast', 'order_check_selection') }}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(modified_date AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
