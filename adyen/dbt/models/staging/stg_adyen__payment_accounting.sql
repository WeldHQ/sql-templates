-- stg_adyen__payment_accounting
-- Thin wrapper over raw `payments_accounting_report`: one row per accounting record,
-- meaning one step in a payment's life (Received, Authorised, SentForSettle,
-- Settled, Refunded, Chargeback and so on). Casts, renames, classifies the record
-- type. No aggregation.
--
-- Grain: one accounting record (merchant account x PSP reference x record type x
-- booking time).
--
-- UNITS. Major units with decimals, as in every Adyen report. The API's minor units
-- do not apply here.
--
-- SIGNS. Kept exactly as Adyen books them on each register (Received, Authorised,
-- Captured, Payable). A record moves an amount off one register and onto the next,
-- so the same payment shows a positive and a negative value on a register over its
-- life. Sum a register across all of a payment's records to get its balance.
--
-- TIME. booking_date and creation_date are wall clock times in the report's time
-- zone, kept as DATETIME next to the time zone code. See settlement_detail.sql for
-- why they are not converted to UTC, and for the type casting and de-duplication
-- approach, which is the same here.

WITH typed AS (
    SELECT
        CAST(row_checksum AS STRING)                                           AS row_checksum,
        CAST(file_name AS STRING)                                              AS file_name,
        CAST(company_account AS STRING)                                        AS company_account,
        CAST(merchant_account AS STRING)                                       AS merchant_account,
        CAST(psp_reference AS STRING)                                          AS psp_reference,
        CAST(merchant_reference AS STRING)                                     AS merchant_reference,
        CAST(modification_psp_reference AS STRING)                             AS modification_psp_reference,
        CAST(modification_merchant_reference AS STRING)                        AS modification_merchant_reference,
        CAST(shopper_reference AS STRING)                                      AS shopper_reference,
        CAST(store AS STRING)                                                  AS store,
        CAST(acquirer AS STRING)                                               AS acquirer,
        LOWER(NULLIF(TRIM(CAST(payment_method AS STRING)), ''))                AS payment_method,
        LOWER(NULLIF(TRIM(CAST(payment_method_variant AS STRING)), ''))        AS payment_method_variant,
        NULLIF(TRIM(CAST(record_type AS STRING)), '')                          AS record_type,
        CAST(user_name AS STRING)                                              AS user_name,
        DATETIME(SAFE_CAST(CAST(booking_date AS STRING) AS TIMESTAMP), 'UTC')  AS booked_at_local,
        DATETIME(SAFE_CAST(CAST(creation_date AS STRING) AS TIMESTAMP), 'UTC') AS created_at_local,
        DATETIME(SAFE_CAST(CAST(payout_date AS STRING) AS TIMESTAMP), 'UTC')   AS payout_at_local,
        NULLIF(TRIM(CAST(time_zone AS STRING)), '')                            AS time_zone,
        SAFE_CAST(payable_batch AS INT64)                                      AS payable_batch,
        UPPER(NULLIF(TRIM(CAST(main_currency AS STRING)), ''))                AS main_currency,
        SAFE_CAST(main_amount AS NUMERIC)                                      AS main_amount,
        UPPER(NULLIF(TRIM(CAST(payment_currency AS STRING)), ''))             AS payment_currency,
        SAFE_CAST(received_pc AS NUMERIC)                                      AS received_pc,
        SAFE_CAST(authorised_pc AS NUMERIC)                                    AS authorised_pc,
        SAFE_CAST(captured_pc AS NUMERIC)                                      AS captured_pc,
        UPPER(NULLIF(TRIM(CAST(settlement_currency AS STRING)), ''))          AS settlement_currency,
        SAFE_CAST(payable_sc AS NUMERIC)                                       AS payable_sc,
        SAFE_CAST(commission_sc AS NUMERIC)                                    AS commission_sc,
        SAFE_CAST(markup_sc AS NUMERIC)                                        AS markup_sc,
        SAFE_CAST(scheme_fees_sc AS NUMERIC)                                   AS scheme_fees_sc,
        SAFE_CAST(interchange_sc AS NUMERIC)                                   AS interchange_sc,
        UPPER(NULLIF(TRIM(CAST(processing_fee_currency AS STRING)), ''))      AS processing_fee_currency,
        SAFE_CAST(processing_fee_fc AS NUMERIC)                                AS processing_fee_fc
    FROM {{ source('adyen', 'payments_accounting_report') }}
    WHERE TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY row_checksum ORDER BY _weld_synced DESC) = 1
)

SELECT
    *,
    LOWER(record_type)                                                         AS record_type_key,
    DATE(booked_at_local)                                                      AS booked_date_local,

    -- Acquirer fees on this record, as Adyen books them. Same rule as the
    -- settlement report: Commission or the three way split, never both.
    COALESCE(commission_sc, 0) + COALESCE(markup_sc, 0)
        + COALESCE(scheme_fees_sc, 0) + COALESCE(interchange_sc, 0)            AS transaction_fees_sc,

    CASE
        WHEN LOWER(record_type) = 'received'                       THEN 'received'
        WHEN LOWER(record_type) IN ('authorised', 'authorisedpending') THEN 'authorised'
        WHEN LOWER(record_type) = 'refused'                        THEN 'refused'
        WHEN LOWER(record_type) IN ('cancelled', 'expired', 'error') THEN 'not_captured'
        WHEN LOWER(record_type) = 'sentforsettle'                  THEN 'sent_for_settle'
        WHEN LOWER(record_type) LIKE 'settled%'                    THEN 'settled'
        WHEN LOWER(record_type) LIKE 'refunded%'                   THEN 'refunded'
        WHEN LOWER(record_type) LIKE '%chargeback%'                THEN 'chargeback'
        WHEN record_type IS NULL                                   THEN 'unclassified'
        ELSE 'other'
    END                                                                        AS record_category
FROM typed
