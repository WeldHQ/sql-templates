-- staging.paypal.transaction
-- PayPal Transaction Search records: one row per transaction id and event code.
-- A single PayPal transaction id can appear with more than one event code (for
-- example a payment and its currency conversion), so both are the key.
--
-- Units and signs: PayPal sends money as decimal strings in major units
-- ("12.50"), signed from your account's point of view. Money in is positive, money
-- out is negative. fee_amount is the PayPal fee on the record, negative when PayPal
-- charges you and positive when a fee is returned (for example on a refund).
--
-- This table holds all records, not only balance-affecting ones, so it
-- includes authorizations, pending and denied transactions. Core decides
-- what counts towards the balance.
--
-- The QUALIFY keeps one row per (id, event_code) in case a record arrives twice.

SELECT
    CAST(id AS STRING)                                                          AS transaction_id,
    CAST(event_code AS STRING)                                                  AS event_code,
    CAST(account_number AS STRING)                                              AS paypal_account_number,
    UPPER(CAST(transaction_info_transaction_status AS STRING))                  AS status,
    CAST(transaction_info_transaction_initiation_date AS TIMESTAMP)             AS initiated_at,
    CAST(transaction_info_transaction_updated_date AS TIMESTAMP)                AS updated_at,
    UPPER(NULLIF(TRIM(CAST(transaction_info_transaction_amount_currency_code AS STRING)), '')) AS currency,
    SAFE_CAST(transaction_info_transaction_amount_value AS NUMERIC)             AS gross_amount,
    UPPER(NULLIF(TRIM(CAST(transaction_info_fee_amount_currency_code AS STRING)), ''))         AS fee_currency,
    COALESCE(SAFE_CAST(transaction_info_fee_amount_value AS NUMERIC), 0)        AS fee_amount,
    SAFE_CAST(transaction_info_sales_tax_amount_value AS NUMERIC)               AS sales_tax_amount,
    SAFE_CAST(transaction_info_shipping_amount_value AS NUMERIC)                AS shipping_amount,
    CAST(transaction_info_invoice_id AS STRING)                                 AS invoice_id,
    CAST(transaction_info_custom_field AS STRING)                               AS custom_field,
    CAST(transaction_info_paypal_reference_id AS STRING)                        AS reference_transaction_id,
    CAST(transaction_info_paypal_reference_id_type AS STRING)                   AS reference_id_type,
    CAST(transaction_info_transaction_subject AS STRING)                        AS subject,
    CAST(transaction_info_payment_method_type AS STRING)                        AS payment_method_type,
    CAST(transaction_info_instrument_type AS STRING)                            AS instrument_type,
    CAST(payer_info_account_id AS STRING)                                       AS payer_account_id,
    CAST(payer_info_email_address AS STRING)                                    AS payer_email,
    COALESCE(
        NULLIF(TRIM(CAST(payer_info_payer_name_alternate_full_name AS STRING)), ''),
        NULLIF(TRIM(CAST(payer_info_payer_name_full_name AS STRING)), ''),
        NULLIF(TRIM(CONCAT(COALESCE(CAST(payer_info_payer_name_given_name AS STRING), ''), ' ',
                           COALESCE(CAST(payer_info_payer_name_surname AS STRING), ''))), '')
    )                                                                           AS payer_name,
    UPPER(NULLIF(TRIM(CAST(payer_info_country_code AS STRING)), ''))            AS payer_country
FROM {{raw.paypal.transaction}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY id, event_code
    ORDER BY transaction_info_transaction_updated_date DESC, _weld_synced DESC
) = 1
