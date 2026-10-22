-- staging.bigcommerce.refund_payment
-- Thin wrapper over raw `refund_payment`: how each refund was paid back (card,
-- store credit, offline). Used only to drop refunds the payment provider declined.

SELECT
    'store_1'                                       AS bigcommerce_store,
    CAST(id AS INT64)                               AS refund_payment_id,
    CAST(refund_id AS INT64)                        AS refund_id,
    NULLIF(TRIM(CAST(provider_id AS STRING)), '')   AS provider_id,
    CAST(amount AS NUMERIC)                         AS amount,
    COALESCE(CAST(offline AS BOOL), FALSE)          AS is_offline,
    COALESCE(CAST(is_declined AS BOOL), FALSE)      AS is_declined
FROM {{raw.bigcommerce.refund_payment}}
