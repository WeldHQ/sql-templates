-- stg_klarna__transaction
-- Thin wrapper over raw `transaction`. One row per money movement Klarna settled:
-- a sale, a return, a fee, the tax on that fee, a holdback and so on. Every row
-- belongs to exactly one payout through payment_reference.
--
-- MINOR UNITS. amount, vat_amount and tax_in_currency_of_registration_country
-- arrive as integers in the minor unit and are divided by 100 here.
--
-- 'unset' AND ''. The connector fills an absent key with the literal string
-- 'unset', and Klarna itself sends an empty string for capture_id on returns and
-- reversals. Both mean "no value" and are turned into NULL, so a COUNT(DISTINCT
-- order_id) does not count 'unset' as an order.
--
-- DIRECTION. Klarna's API documents type but not a sign convention for amount.
-- ledger_direction says which way each type moves the merchant's money (+1 in,
-- -1 out) and signed_amount applies it to ABS(amount), so the result is the same
-- whether a given account returns signed or unsigned amounts. Three types have no
-- documented direction (COMMISSION, CORRECTION, REVERSAL_MERCHANT_PROTECTION):
-- they get ledger_direction NULL and signed_amount keeps Klarna's raw value.
-- Check them against the payout PDF before relying on any net figure that
-- includes them.

SELECT
    'account_1'                                                         AS klarna_account,
    CAST(merchant_id AS STRING)                                         AS merchant_id,
    CAST(payment_reference AS STRING)                                   AS payment_reference,
    NULLIF(NULLIF(TRIM(CAST(capture_id AS STRING)), ''), 'unset')       AS capture_id,
    NULLIF(NULLIF(TRIM(CAST(order_id AS STRING)), ''), 'unset')         AS order_id,
    NULLIF(NULLIF(TRIM(CAST(short_order_id AS STRING)), ''), 'unset')   AS short_order_id,
    NULLIF(NULLIF(TRIM(CAST(refund_id AS STRING)), ''), 'unset')        AS refund_id,
    NULLIF(NULLIF(TRIM(CAST(merchant_capture_reference AS STRING)), ''), 'unset') AS merchant_capture_reference,
    NULLIF(NULLIF(TRIM(CAST(merchant_refund_reference AS STRING)), ''), 'unset')  AS merchant_refund_reference,
    NULLIF(TRIM(CAST(merchant_reference_1 AS STRING)), '')              AS merchant_reference_1,
    NULLIF(TRIM(CAST(merchant_reference_2 AS STRING)), '')              AS merchant_reference_2,
    UPPER(NULLIF(TRIM(CAST(type AS STRING)), ''))                       AS transaction_type,
    UPPER(NULLIF(TRIM(CAST(detailed_type AS STRING)), ''))              AS detailed_type,
    ROUND(CAST(amount AS NUMERIC) / 100, 2)                             AS amount,
    -- VAT on Klarna's own fees, not on the goods sold.
    ROUND(CAST(vat_amount AS NUMERIC) / 100, 2)                         AS fee_vat_amount,
    ROUND(CAST(tax_in_currency_of_registration_country AS NUMERIC) / 100, 2) AS fee_tax_in_registration_currency,
    UPPER(NULLIF(TRIM(CAST(currency_code_of_registration_country AS STRING)), '')) AS registration_currency_code,
    UPPER(NULLIF(TRIM(CAST(currency_code AS STRING)), ''))              AS currency_code,
    CAST(sale_date AS TIMESTAMP)                                        AS sale_at,
    CAST(capture_date AS TIMESTAMP)                                     AS capture_at,
    UPPER(NULLIF(TRIM(CAST(purchase_country AS STRING)), ''))           AS purchase_country,
    UPPER(NULLIF(TRIM(CAST(shipping_address_country AS STRING)), ''))   AS shipping_country,
    NULLIF(TRIM(CAST(initial_payment_method_type AS STRING)), '')       AS payment_method_type,
    CAST(initial_number_of_installments AS INT64)                       AS number_of_installments,
    NULLIF(TRIM(CAST(klarna_comment AS STRING)), '')                    AS klarna_comment,
    NULLIF(TRIM(CAST(reversal_reference AS STRING)), '')                AS reversal_reference,
    CASE
        WHEN UPPER(TRIM(CAST(type AS STRING))) IN ('SALE', 'FEE_REFUND', 'CREDIT', 'RELEASE') THEN 1
        WHEN UPPER(TRIM(CAST(type AS STRING))) IN ('RETURN', 'FEE', 'TAX', 'REVERSAL', 'CHARGE', 'HOLDBACK') THEN -1
    END                                                             AS ledger_direction,
    CASE
        WHEN UPPER(TRIM(CAST(type AS STRING))) IN ('SALE', 'FEE_REFUND', 'CREDIT', 'RELEASE')
            THEN ABS(ROUND(CAST(amount AS NUMERIC) / 100, 2))
        WHEN UPPER(TRIM(CAST(type AS STRING))) IN ('RETURN', 'FEE', 'TAX', 'REVERSAL', 'CHARGE', 'HOLDBACK')
            THEN -ABS(ROUND(CAST(amount AS NUMERIC) / 100, 2))
        ELSE ROUND(CAST(amount AS NUMERIC) / 100, 2)
    END                                                             AS signed_amount
FROM {{ source('klarna', 'transaction') }}
