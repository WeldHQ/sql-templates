-- stg_bigcommerce__refund_line_item
-- Thin wrapper over raw `refund_line_item`: what a refund covered.
--
-- THE COLUMN CALLED product_id IS NOT A PRODUCT ID. The connector lands BigCommerce's
-- `item_id` under that name, and what item_id points at depends on item_type:
--
--   PRODUCT, GIFT_WRAPPING   the order line (order_line_item.id)
--   SHIPPING, HANDLING       the order's shipping address
--   ORDER                    the order itself
--
-- Joining it to product.id matches the wrong rows, silently. It is renamed to
-- item_id here and only ever joined to order_line_item.id, for PRODUCT rows.
--
-- quantity is set for PRODUCT rows only. requested_amount is often NULL on PRODUCT
-- rows, because a quantity refund lets BigCommerce compute the money itself.

SELECT
    'store_1'                                       AS bigcommerce_store,
    CAST(refund_id AS INT64)                        AS refund_id,
    CAST(product_id AS INT64)                       AS item_id,
    UPPER(NULLIF(TRIM(CAST(item_type AS STRING)), '')) AS item_type,
    CAST(quantity AS INT64)                         AS quantity,
    CAST(requested_amount AS NUMERIC)               AS requested_amount,
    NULLIF(TRIM(CAST(reason AS STRING)), '')        AS reason
FROM {{ source('bigcommerce', 'refund_line_item') }}
