-- stg_quickbooks__journal_report_line
-- The second and later lines of every transaction in the Journal report. They carry
-- no date or transaction type; core.quickbooks.general_ledger takes those from the
-- transaction's first line in staging.quickbooks.journal_report.
--
-- Grain: one row per transaction line after the first (transaction id x document
-- number x line index).
--
-- Amounts are in the company's home currency. Debit and credit are both positive.
--
-- Single company. To add another, UNION ALL a second block below pointing at that
-- company's connector with a different quickbooks_company label.

SELECT
    'company_1'                                        AS quickbooks_company,
    CAST(journal_transaction_id AS STRING)             AS transaction_id,
    CAST(journal_num AS STRING)                        AS transaction_number,
    CAST(index AS INT64)                               AS line_index,
    NULLIF(TRIM(CAST(memo_description AS STRING)), '') AS memo,
    CAST(account_id AS STRING)                         AS account_id,
    CAST(account AS STRING)                            AS account_name,
    COALESCE(CAST(debit AS NUMERIC), 0)                AS debit,
    COALESCE(CAST(credit AS NUMERIC), 0)               AS credit
FROM {{ source('quickbooks', 'journal_report_line') }}
WHERE journal_transaction_id IS NOT NULL
