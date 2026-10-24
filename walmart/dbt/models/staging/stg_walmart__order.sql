-- stg_walmart__order
-- Thin wrapper over raw `order`: one row per purchase order. Casts, renames,
-- keeps the latest version. No business logic.
--
-- One account. To add another, UNION ALL a second block with a different
-- walmart_seller label; purchase order ids are only unique within an account,
-- and walmart_seller is part of every join key downstream.
--
-- Customer name, email, phone and street address are left out on purpose. The
-- state is kept for geography.

SELECT
    'seller_1'                                                  AS walmart_seller,
    CAST(purchase_order_id AS STRING)                           AS purchase_order_id,
    CAST(customer_order_id AS STRING)                           AS customer_order_id,
    CAST(order_type AS STRING)                                  AS order_type,
    CAST(order_date AS TIMESTAMP)                               AS ordered_at,
    UPPER(CAST(order_summary_total_amount_currency_unit AS STRING)) AS currency,
    CAST(order_summary_total_amount_currency_amount AS NUMERIC) AS order_total,
    CAST(ship_node_type AS STRING)                              AS ship_node_type,
    CAST(ship_node_name AS STRING)                              AS ship_node_name,
    UPPER(CAST(shipping_info_postal_address_state AS STRING))   AS ship_to_state,
    UPPER(CAST(shipping_info_postal_address_country AS STRING)) AS ship_to_country,
    CAST(shipping_info_method_code AS STRING)                   AS shipping_method
FROM {{ source('walmart', 'order') }}
WHERE purchase_order_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_order_id ORDER BY _weld_synced DESC) = 1
