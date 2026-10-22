-- stg_dandomain_webshop__order_discount_code
-- Thin wrapper over raw `order_discount_code`: discount codes and gift cards
-- redeemed on an order. `discount` is the amount actually given; `value` is the
-- code's setting (a percentage or a fixed amount, according to `type`). Latest copy
-- per row.
--
-- The amount is stored positive and flipped negative here, so net = gross +
-- discounts is plain addition downstream.

SELECT
    'shop_1'                                        AS dandomain_shop,
    CAST(id AS INT64)                               AS order_discount_code_id,
    CAST(order_id AS INT64)                         AS order_id,
    CAST(discount_id AS INT64)                      AS discount_id,
    NULLIF(TRIM(CAST(title AS STRING)), '')         AS title,
    LOWER(NULLIF(TRIM(CAST(type AS STRING)), ''))   AS discount_type,
    -1 * ABS(CAST(discount AS NUMERIC))             AS discount_amount,
    COALESCE(CAST(vat AS BOOL), FALSE)              AS has_vat
FROM {{ source('dandomain_webshop', 'order_discount_code') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
