-- stg_toast__payment
-- Thin wrapper over raw `order_check_payment`. One row per payment on a check.
-- amount excludes the tip; tip_amount is the tip on that payment.

SELECT
    CAST(guid AS STRING)                    AS payment_id,
    CAST(order_check_guid AS STRING)        AS check_id,
    CAST(order_guid AS STRING)              AS order_id,
    CAST(restaurant_guid AS STRING)         AS restaurant_id,
    UPPER(CAST(type AS STRING))             AS payment_type,
    UPPER(CAST(card_type AS STRING))        AS card_type,
    UPPER(CAST(payment_status AS STRING))   AS payment_status,
    CAST(amount AS FLOAT64)                 AS amount,
    COALESCE(CAST(tip_amount AS FLOAT64), 0) AS tip_amount,
    COALESCE(CAST(refund_refund_amount AS FLOAT64), 0)     AS refund_amount,
    COALESCE(CAST(refund_tip_refund_amount AS FLOAT64), 0) AS tip_refund_amount,
    CAST(paid_date AS TIMESTAMP)            AS paid_at
FROM {{ source('toast', 'order_check_payment') }}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(guid AS STRING) ORDER BY _weld_synced DESC) = 1
