-- staging.tiktok_shop.order_line_items
-- Thin wrapper over raw `order_line_items`. Casts, renames, de-duplicates.
--
-- ONE ROW IS ONE UNIT. TikTok's order API has no quantity field: an order for
-- three of the same SKU arrives as three line items with three ids. Units are
-- therefore COUNT(*), never a sum of a quantity column.
--
-- Prices are per unit, in the line's currency:
--   original_price  list price before any discount
--   seller_discount discount the seller funds
--   platform_discount discount TikTok funds (paid back to the seller in settlement)
--   sale_price      what the customer paid for the unit

SELECT
    'account_1'                              AS tiktok_account,
    CAST(shop_id AS STRING)                  AS shop_id,
    CAST(order_id AS STRING)                 AS order_id,
    CAST(id AS STRING)                       AS line_item_id,
    CAST(product_id AS STRING)               AS product_id,
    CAST(sku_id AS STRING)                   AS sku_id,
    CAST(seller_sku AS STRING)               AS seller_sku,
    CAST(product_name AS STRING)             AS product_name,
    CAST(sku_name AS STRING)                 AS sku_name,
    UPPER(CAST(display_status AS STRING))    AS display_status,
    CAST(cancel_reason AS STRING)            AS cancel_reason,
    UPPER(CAST(currency AS STRING))          AS currency,
    COALESCE(is_gift, FALSE)                 AS is_gift,
    COALESCE(CAST(original_price AS NUMERIC), 0)    AS original_price,
    COALESCE(CAST(seller_discount AS NUMERIC), 0)   AS seller_discount,
    COALESCE(CAST(platform_discount AS NUMERIC), 0) AS platform_discount,
    COALESCE(CAST(sale_price AS NUMERIC), 0)        AS sale_price
FROM {{raw.tiktok_shop.order_line_items}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, id ORDER BY _weld_synced DESC) = 1
