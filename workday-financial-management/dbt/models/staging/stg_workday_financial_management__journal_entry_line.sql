-- stg_workday_financial_management__journal_entry_line
-- Journal lines: ledger account, debit and credit.
--
-- Grain: journal entry x line index.
--
-- Two sets of amounts. debit_amount and credit_amount are in the line's
-- transaction currency (line_currency). ledger_debit_amount and
-- ledger_credit_amount are in the ledger currency, the company's base currency.
-- Workday may leave the ledger amounts empty when the two currencies are the
-- same, so ledger_debit and ledger_credit fall back to the transaction amounts.
-- All four are positive; an empty side is 0.
--
-- account_set_code is the account set the line's ledger account belongs to
-- (for example "Standard"), and ledger_account_code is the account's identifier
-- within that set. Together they are the key into
-- staging.workday_financial_management.ledger_account.
--
-- Single tenant. To add another, UNION ALL a second block below pointing at that
-- tenant's connector with a different workday_tenant label.

SELECT
    'tenant_1'                                       AS workday_tenant,
    CAST(journal_entry_id AS STRING)                 AS journal_entry_id,
    CAST(index AS INT64)                             AS line_index,
    CAST(journal_line_number AS INT64)               AS journal_line_number,
    CAST(account_set_id AS STRING)                   AS account_set_code,
    CAST(ledger_account_id AS STRING)                AS ledger_account_wid,
    CAST(ledger_account_code AS STRING)              AS ledger_account_code,
    CAST(ledger_account_descriptor AS STRING)        AS ledger_account_name,
    CAST(line_company_id AS STRING)                  AS line_company_id,
    UPPER(CAST(currency_code AS STRING))             AS line_currency,
    COALESCE(CAST(debit_amount AS NUMERIC), 0)       AS debit,
    COALESCE(CAST(credit_amount AS NUMERIC), 0)      AS credit,
    COALESCE(
        CAST(ledger_debit_amount AS NUMERIC),
        CAST(debit_amount AS NUMERIC),
        0
    )                                                AS ledger_debit,
    COALESCE(
        CAST(ledger_credit_amount AS NUMERIC),
        CAST(credit_amount AS NUMERIC),
        0
    )                                                AS ledger_credit,
    NULLIF(TRIM(CAST(memo AS STRING)), '')           AS memo
FROM {{ source('workday_financial_management', 'journal_entry_line') }}
