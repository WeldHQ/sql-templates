-- stg_bigcommerce__order_line_item_discount
-- Thin wrapper over raw `order_line_item_discount`: one row per discount applied to
-- an order line (coupon or promotion). BigCommerce reports the amount as a positive
-- magnitude; it is flipped negative here so that net = gross + discounts is plain
-- addition everywhere downstream.

SELECT
    'store_1'                                   AS bigcommerce_store,
    CAST(id AS STRING)                          AS discount_id,
    CAST(order_id AS INT64)                     AS order_id,
    CAST(order_line_item_id AS INT64)           AS order_line_item_id,
    NULLIF(TRIM(CAST(name AS STRING)), '')      AS discount_name,
    NULLIF(TRIM(CAST(code AS STRING)), '')      AS coupon_code,
    -1 * ABS(CAST(amount AS NUMERIC))           AS discount_amount
FROM {{ source('bigcommerce', 'order_line_item_discount') }}
