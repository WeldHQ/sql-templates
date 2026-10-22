-- stg_salesforce_commerce_cloud__order_product_item
-- One row per product line, unpacked from the order's `product_items` column.
--
-- WHY THIS IS PARSED HERE. The connector flattens nested objects on the order
-- (billing_address_*, customer_info_*) but stores arrays as JSON text, so the
-- order's lines arrive as one string. This model turns that string into rows,
-- once, so nothing downstream touches JSON.
--
-- KEY NAMES. The Commerce API names fields in camelCase (productId,
-- priceAfterOrderDiscount); older OCAPI payloads use snake_case. Each field reads
-- both spellings. If a column comes back NULL on every row, open one product_items
-- value and check the key names against the paths below.
--
-- The three prices are line totals (unit price x quantity), not unit prices:
--   price                       before any adjustment
--   price_after_item_discount   after promotions on this line
--   price_after_order_discount  after this line's share of order-level promotions
-- In a gross-taxation site all three include tax.

WITH exploded AS (
    SELECT
        CAST(o.order_no AS STRING)  AS order_no,
        item_json                   AS item_json,
        item_position               AS item_position
    FROM {{ source('salesforce_commerce_cloud', 'order') }} o,
    UNNEST(JSON_QUERY_ARRAY(CAST(o.product_items AS STRING))) AS item_json WITH OFFSET AS item_position
)

SELECT
    'instance_1'                                                    AS sfcc_instance,
    order_no,
    item_position,
    COALESCE(JSON_VALUE(item_json, '$.itemId'), JSON_VALUE(item_json, '$.item_id'))             AS item_id,
    COALESCE(JSON_VALUE(item_json, '$.productId'), JSON_VALUE(item_json, '$.product_id'))       AS product_id,
    COALESCE(JSON_VALUE(item_json, '$.productName'), JSON_VALUE(item_json, '$.product_name'))   AS product_name,
    SAFE_CAST(JSON_VALUE(item_json, '$.quantity') AS NUMERIC)                              AS quantity,
    SAFE_CAST(COALESCE(JSON_VALUE(item_json, '$.basePrice'), JSON_VALUE(item_json, '$.base_price')) AS NUMERIC) AS base_price,
    SAFE_CAST(JSON_VALUE(item_json, '$.price') AS NUMERIC)                                 AS price,
    SAFE_CAST(COALESCE(JSON_VALUE(item_json, '$.priceAfterItemDiscount'),
                       JSON_VALUE(item_json, '$.price_after_item_discount')) AS NUMERIC)   AS price_after_item_discount,
    SAFE_CAST(COALESCE(JSON_VALUE(item_json, '$.priceAfterOrderDiscount'),
                       JSON_VALUE(item_json, '$.price_after_order_discount')) AS NUMERIC)  AS price_after_order_discount,
    SAFE_CAST(COALESCE(JSON_VALUE(item_json, '$.adjustedTax'), JSON_VALUE(item_json, '$.adjusted_tax')) AS NUMERIC) AS adjusted_tax,
    COALESCE(SAFE_CAST(COALESCE(JSON_VALUE(item_json, '$.bonusProductLineItem'),
                                JSON_VALUE(item_json, '$.bonus_product_line_item')) AS BOOL), FALSE) AS is_bonus_item
FROM exploded
