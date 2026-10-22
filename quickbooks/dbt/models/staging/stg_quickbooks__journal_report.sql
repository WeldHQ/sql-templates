-- stg_quickbooks__journal_report
-- The first line of every transaction in QuickBooks Online's Journal report, the
-- report that lists debits and credits for every transaction type (invoices,
-- bills, payments, deposits, journal entries, and so on). Weld stores the first
-- line of each transaction here, with its date and type, and the remaining lines in
-- journal_report_line.
--
-- Grain: one row per transaction (transaction id x document number).
--
-- The raw table is keyed on transaction id, number and the first line's account,
-- so a transaction whose first line moved to another account after an edit can
-- leave an older copy behind. Only the most recently synced copy is kept.
--
-- Amounts are in the company's home currency. Debit and credit are both positive;
-- an empty side is NULL in raw and 0 here.
--
-- Single company. To add another, UNION ALL a second block below pointing at that
-- company's connector with a different quickbooks_company label.

SELECT
    quickbooks_company,
    transaction_id,
    transaction_number,
    transaction_date,
    transaction_type,
    name,
    name_id,
    memo,
    account_id,
    account_name,
    debit,
    credit
FROM (
    SELECT
        'company_1'                                        AS quickbooks_company,
        CAST(transaction_id AS STRING)                     AS transaction_id,
        CAST(num AS STRING)                                AS transaction_number,
        DATE(CAST(date AS TIMESTAMP))                      AS transaction_date,
        NULLIF(TRIM(CAST(transaction_type AS STRING)), '') AS transaction_type,
        NULLIF(TRIM(CAST(name AS STRING)), '')             AS name,
        NULLIF(TRIM(CAST(name_id AS STRING)), '')          AS name_id,
        NULLIF(TRIM(CAST(memo_description AS STRING)), '') AS memo,
        CAST(account_id AS STRING)                         AS account_id,
        CAST(account AS STRING)                            AS account_name,
        COALESCE(CAST(debit AS NUMERIC), 0)                AS debit,
        COALESCE(CAST(credit AS NUMERIC), 0)               AS credit,
        ROW_NUMBER() OVER (
            PARTITION BY CAST(transaction_id AS STRING), CAST(num AS STRING)
            ORDER BY _weld_synced DESC
        )                                                  AS version_rank
    FROM {{ source('quickbooks', 'journal_report') }}
)
WHERE version_rank = 1
