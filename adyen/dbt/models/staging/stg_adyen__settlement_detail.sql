-- stg_adyen__settlement_detail
-- Thin wrapper over raw `settlement_detail_report`: one row per journal entry in a
-- settlement batch. Casts, renames, signs the amounts and classifies each entry. No
-- aggregation.
--
-- Grain: one journal entry (merchant account x batch x PSP reference x journal type).
--
-- UNITS. Adyen's reports carry amounts in major units with decimals (EUR 12.34 is
-- 12.34). The Adyen API uses minor units (1234), but this table comes from the
-- reports, so nothing is divided by 100 here. Do not apply a minor unit conversion.
--
-- TYPES. Weld infers each column's type from a sample of the CSV, so a column can
-- land as FLOAT64 in one warehouse and STRING in another. Every column is cast
-- explicitly for that reason, and dates go through STRING first.
--
-- TIME. creation_date is the wall clock time in the report's time zone (the
-- account's Customer Area setting), not UTC. It is kept as a DATETIME next to the
-- time zone code rather than converted, because Adyen uses abbreviations such as
-- CET and CEST that are not reliable IANA names.
--
-- DE-DUPLICATION. Each row carries row_checksum, a hash of the row's content.
-- Re-delivering the same report produces the same checksums, so keeping one row per
-- checksum removes re-deliveries. Generate this report at one level only (company
-- or merchant account): the same entry in two differently configured reports has a
-- different checksum and would be counted twice.

WITH typed AS (
    SELECT
        CAST(row_checksum AS STRING)                                           AS row_checksum,
        CAST(file_name AS STRING)                                              AS file_name,
        CAST(company_account AS STRING)                                        AS company_account,
        CAST(merchant_account AS STRING)                                       AS merchant_account,
        CAST(psp_reference AS STRING)                                          AS psp_reference,
        CAST(merchant_reference AS STRING)                                     AS merchant_reference,
        LOWER(NULLIF(TRIM(CAST(payment_method AS STRING)), ''))                AS payment_method,
        LOWER(NULLIF(TRIM(CAST(payment_method_variant AS STRING)), ''))        AS payment_method_variant,
        DATETIME(SAFE_CAST(CAST(creation_date AS STRING) AS TIMESTAMP), 'UTC') AS created_at_local,
        NULLIF(TRIM(CAST(time_zone AS STRING)), '')                            AS time_zone,
        NULLIF(TRIM(CAST(type AS STRING)), '')                                 AS journal_type,
        CAST(modification_reference AS STRING)                                 AS modification_reference,
        CAST(modification_merchant_reference AS STRING)                        AS modification_merchant_reference,
        SAFE_CAST(batch_number AS INT64)                                       AS batch_number,
        UPPER(NULLIF(TRIM(CAST(gross_currency AS STRING)), ''))               AS gross_currency,
        SAFE_CAST(gross_debit_gc AS NUMERIC)                                   AS gross_debit_gc,
        SAFE_CAST(gross_credit_gc AS NUMERIC)                                  AS gross_credit_gc,
        SAFE_CAST(exchange_rate AS NUMERIC)                                    AS exchange_rate,
        UPPER(NULLIF(TRIM(CAST(net_currency AS STRING)), ''))                 AS net_currency,
        SAFE_CAST(net_debit_nc AS NUMERIC)                                     AS net_debit_nc,
        SAFE_CAST(net_credit_nc AS NUMERIC)                                    AS net_credit_nc,
        SAFE_CAST(commission_nc AS NUMERIC)                                    AS commission_nc,
        SAFE_CAST(markup_nc AS NUMERIC)                                        AS markup_nc,
        SAFE_CAST(scheme_fees_nc AS NUMERIC)                                   AS scheme_fees_nc,
        SAFE_CAST(interchange_nc AS NUMERIC)                                   AS interchange_nc
    FROM {{ source('adyen', 'settlement_detail_report') }}
    WHERE TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY row_checksum ORDER BY _weld_synced DESC) = 1
)

SELECT
    *,
    DATE(created_at_local)                                                     AS created_date_local,

    -- Signed amounts: credits to the batch positive, debits negative. A plain SUM
    -- over a batch is then the batch's net movement.
    COALESCE(net_credit_nc, 0) - COALESCE(net_debit_nc, 0)                     AS net_amount_nc,
    COALESCE(gross_credit_gc, 0) - COALESCE(gross_debit_gc, 0)                 AS gross_amount_gc,

    -- Transaction fees withheld from this entry, positive is a cost. Adyen fills
    -- either Commission (blended pricing, or no interchange level data) or the
    -- Markup, Scheme Fees and Interchange split, never both, so adding all four is
    -- the total in either case. Commission is negative on externally settled refunds.
    COALESCE(commission_nc, 0) + COALESCE(markup_nc, 0)
        + COALESCE(scheme_fees_nc, 0) + COALESCE(interchange_nc, 0)            AS transaction_fees_nc,

    -- One classification, used by every core model. Adyen adds journal types over
    -- time; anything not listed lands in 'other' and stays in the batch total.
    CASE
        WHEN LOWER(journal_type) LIKE 'settled%'                    THEN 'settled'
        WHEN LOWER(journal_type) LIKE 'refunded%'                   THEN 'refund'
        WHEN LOWER(journal_type) LIKE '%chargeback%'                THEN 'chargeback'
        WHEN LOWER(journal_type) = 'fee'                            THEN 'adyen_fee'
        WHEN LOWER(journal_type) = 'invoicededuction'               THEN 'invoice_deduction'
        WHEN LOWER(journal_type) IN ('depositcorrection', 'reserveadjustment') THEN 'reserve'
        WHEN LOWER(journal_type) = 'balancetransfer'                THEN 'balance_transfer'
        WHEN LOWER(journal_type) = 'merchantpayout'                 THEN 'payout'
        WHEN journal_type IS NULL                                   THEN 'unclassified'
        ELSE 'other'
    END                                                                        AS entry_category
FROM typed
