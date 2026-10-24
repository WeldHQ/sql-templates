-- stg_chargebee__credit_note
-- Thin wrapper over raw `credit_note`. One row per credit note. Casts, renames,
-- converts minor units to major units, drops deleted credit notes.
--
-- Amounts on a credit note are POSITIVE in Chargebee. They are kept positive
-- here; core subtracts them where a credit reduces revenue.
-- Minor units and the zero-decimal list work as in staging.chargebee.invoice.

WITH source AS (
    SELECT
        *,
        UPPER(NULLIF(TRIM(CAST(currency_code AS STRING)), '')) AS currency,
        CASE
            WHEN UPPER(CAST(currency_code AS STRING)) IN ('JPY', 'KRW', 'XAF', 'XOF') THEN 1
            ELSE 100
        END AS minor_unit_divisor
    FROM {{ source('chargebee', 'credit_note') }}
    WHERE COALESCE(CAST(deleted AS BOOL), FALSE) = FALSE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
)

SELECT
    CAST(id AS STRING)                                          AS credit_note_id,
    CAST(customer_id AS STRING)                                 AS customer_id,
    CAST(subscription_id AS STRING)                             AS subscription_id,
    -- The invoice this credit note was raised against.
    CAST(invoice_id AS STRING)                                  AS reference_invoice_id,
    -- adjustment, refundable or store.
    LOWER(CAST(type AS STRING))                                 AS credit_note_type,
    -- subscription_change, subscription_cancellation, write_off, chargeback, ...
    LOWER(CAST(reason_code AS STRING))                          AS reason_code,
    CAST(create_reason_code AS STRING)                          AS create_reason_code,
    -- adjusted, refunded, refund_due or voided.
    LOWER(CAST(status AS STRING))                               AS status,

    currency,
    minor_unit_divisor,

    CAST(`date` AS TIMESTAMP)                                   AS credited_at,
    DATE(CAST(`date` AS TIMESTAMP))                             AS credit_note_date,
    CAST(voided_at AS TIMESTAMP)                                AS voided_at,

    CAST(sub_total AS NUMERIC) / minor_unit_divisor             AS sub_total,
    CAST(amount_allocated AS NUMERIC) / minor_unit_divisor      AS amount_allocated,
    CAST(amount_refunded AS NUMERIC) / minor_unit_divisor       AS amount_refunded,
    CAST(amount_available AS NUMERIC) / minor_unit_divisor      AS amount_available
FROM source
