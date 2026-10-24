-- stg_toast__check
-- Thin wrapper over raw `order_check`. One row per check (an order can be split
-- into several checks). amount is after discounts and before tax; total_amount
-- includes tax.

SELECT
    CAST(guid AS STRING)                AS check_id,
    CAST(order_guid AS STRING)          AS order_id,
    CAST(restaurant_guid AS STRING)     AS restaurant_id,
    CAST(amount AS FLOAT64)             AS amount,
    CAST(tax_amount AS FLOAT64)         AS tax_amount,
    CAST(total_amount AS FLOAT64)       AS total_amount,
    UPPER(CAST(payment_status AS STRING)) AS payment_status,
    COALESCE(voided, FALSE)             AS is_voided,
    COALESCE(deleted, FALSE)            AS is_deleted
FROM {{ source('toast', 'order_check') }}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(modified_date AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
