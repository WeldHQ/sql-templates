-- staging.tiktok_shop.order
-- Thin wrapper over raw `order`. Casts, renames, keeps the latest version of each
-- order. No business logic.
--
-- One connection. To add another TikTok login, UNION ALL a second block with a
-- different tiktok_account label. Order IDs are unique per shop, and shop_id plus
-- tiktok_account are part of every join key downstream.
--
-- Recipient address and buyer contact columns are left out on purpose: no report
-- here needs personal data, and staging is the place to keep it out.

SELECT
    'account_1'                                        AS tiktok_account,
    CAST(shop_id AS STRING)                            AS shop_id,
    CAST(id AS STRING)                                 AS order_id,
    UPPER(CAST(status AS STRING))                      AS order_status,
    UPPER(CAST(payment_currency AS STRING))            AS currency,

    CAST(create_time AS TIMESTAMP)                     AS created_at,
    CAST(paid_time AS TIMESTAMP)                       AS paid_at,
    CAST(cancel_time AS TIMESTAMP)                     AS cancelled_at,
    CAST(update_time AS TIMESTAMP)                     AS updated_at,
    CAST(delivery_time AS TIMESTAMP)                   AS delivered_at,

    CAST(fulfillment_type AS STRING)                   AS fulfillment_type,
    CAST(delivery_type AS STRING)                      AS delivery_type,
    CAST(order_type AS STRING)                         AS order_type,
    CAST(cancel_reason AS STRING)                      AS cancel_reason,
    CAST(cancellation_initiator AS STRING)             AS cancellation_initiator,
    UPPER(CAST(recipient_address_region_code AS STRING)) AS region_code,

    COALESCE(is_cod, FALSE)                            AS is_cod,
    COALESCE(is_sample_order, FALSE)                   AS is_sample_order,
    COALESCE(is_replacement_order, FALSE)              AS is_replacement_order,
    COALESCE(is_exchange_order, FALSE)                 AS is_exchange_order,

    -- Order-level money, in the order's payment currency. TikTok returns these as
    -- decimal strings; the connector lands them as numbers.
    CAST(payment_original_total_product_price AS NUMERIC) AS original_total_product_price,
    CAST(payment_seller_discount AS NUMERIC)           AS seller_discount,
    CAST(payment_platform_discount AS NUMERIC)         AS platform_discount,
    CAST(payment_sub_total AS NUMERIC)                 AS sub_total,
    CAST(payment_shipping_fee AS NUMERIC)              AS shipping_fee,
    CAST(payment_tax AS NUMERIC)                       AS tax,
    CAST(payment_total_amount AS NUMERIC)              AS total_amount
FROM {{raw.tiktok_shop.order}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, id ORDER BY update_time DESC, _weld_synced DESC) = 1
