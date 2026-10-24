-- staging.workday_financial_management.journal_entry_line
-- Journal lines: ledger account, debit and credit.
--
-- Grain: journal entry x line index.
--
-- Two sets of amounts. debit_amount and credit_amount are in the line's
-- transaction currency (line_currency). ledger_debit_amount and
-- ledger_credit_amount are in the ledger currency, the company's base currency.
-- Workday can leave the ledger amounts empty when the line is already in the
-- base currency. They are kept here as delivered, NULL included; core falls back
-- to the transaction amounts only when the line currency is the company's base
-- currency, since doing so for a foreign-currency line would mix currencies.
-- currency_rate is the rate Workday used from the transaction currency to the
-- ledger currency.
--
-- Signs: amounts are normally positive, with an empty side 0. A company set to
-- "keep debit/credit and reverse sign" books reversals on the original side with
-- a negative amount instead of swapping sides, so negative debits and credits
-- are valid. Net amounts (debit - credit) are right either way.
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
    CAST(currency_rate AS NUMERIC)                   AS currency_rate,
    CAST(ledger_debit_amount AS NUMERIC)             AS ledger_debit_amount,
    CAST(ledger_credit_amount AS NUMERIC)            AS ledger_credit_amount,
    NULLIF(TRIM(CAST(memo AS STRING)), '')           AS memo
FROM {{raw.workday_financial_management.journal_entry_line}}
