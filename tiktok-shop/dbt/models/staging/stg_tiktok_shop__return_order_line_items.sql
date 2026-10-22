-- stg_tiktok_shop__return_order_line_items
-- Thin wrapper over raw `return_order_line_items`: one row per returned order
-- line item, which (as on the order side) is one unit.
--
-- The refund amounts are what the customer gets back, so they exclude the
-- TikTok-funded platform discount the customer never paid. product_id is not on
-- this table; core resolves it through order_line_item_id.

SELECT
    'account_1'                                       AS tiktok_account,
    CAST(shop_id AS STRING)                           AS shop_id,
    CAST(return_id AS STRING)                         AS return_id,
    CAST(return_line_item_id AS STRING)               AS return_line_item_id,
    CAST(order_id AS STRING)                          AS order_id,
    CAST(order_line_item_id AS STRING)                AS line_item_id,
    CAST(sku_id AS STRING)                            AS sku_id,
    CAST(seller_sku AS STRING)                        AS seller_sku,
    UPPER(CAST(refund_amount_currency AS STRING))     AS currency,
    COALESCE(CAST(refund_amount_refund_subtotal AS NUMERIC), 0)     AS refund_subtotal,
    COALESCE(CAST(refund_amount_refund_shipping_fee AS NUMERIC), 0) AS refund_shipping_fee,
    COALESCE(CAST(refund_amount_refund_tax AS NUMERIC), 0)          AS refund_tax,
    COALESCE(CAST(refund_amount_refund_total AS NUMERIC), 0)        AS refund_total
FROM {{ source('tiktok_shop', 'return_order_line_items') }}
WHERE return_line_item_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, return_id, return_line_item_id ORDER BY _weld_synced DESC) = 1
