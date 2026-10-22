-- core.quickbooks.general_ledger
-- Every debit and credit QuickBooks Online posted, one row per journal line, with
-- the account's classification attached. This is the base for the trial balance
-- and the P&L, and the table to filter when someone asks "what hit this account".
--
-- Grain: company x transaction id x document number x line position. Line position
-- 0 is the transaction's first line; later lines keep the order of the report.
--
-- Source: QuickBooks' Journal report, which covers every transaction type that
-- posts to the ledger (invoices, sales receipts, payments, bills, bill payments,
-- checks, expenses, deposits, transfers, journal entries). Reading it avoids
-- rebuilding the ledger from a dozen transaction streams, each with its own line
-- layout and its own idea of which account is hit.
--
-- Currency: the company's home currency. Foreign-currency transactions are already
-- converted by QuickBooks at the transaction's exchange rate.
--
-- Signs:
--   debit, credit     both positive, exactly as QuickBooks shows them
--   net_debit         debit - credit. Sums to zero over any complete transaction,
--                     and over the whole ledger.
--   amount_natural    signed by the account's normal balance: debit - credit for
--                     Asset and Expense accounts, credit - debit for Liability,
--                     Equity and Revenue. Positive means the account grew.

WITH lines AS (
    SELECT
        quickbooks_company,
        transaction_id,
        transaction_number,
        0           AS line_position,
        memo,
        account_id,
        account_name,
        debit,
        credit
    FROM {{staging.quickbooks.journal_report}}

    UNION ALL

    SELECT
        quickbooks_company,
        transaction_id,
        transaction_number,
        line_index + 1 AS line_position,
        memo,
        account_id,
        account_name,
        debit,
        credit
    FROM {{staging.quickbooks.journal_report_line}}
)

SELECT
    l.quickbooks_company,
    h.transaction_date,
    DATE_TRUNC(h.transaction_date, MONTH)           AS transaction_month,
    h.transaction_type,
    l.transaction_id,
    l.transaction_number,
    l.line_position,
    h.name,
    h.name_id,
    l.memo,
    l.account_id,
    COALESCE(a.account_name, l.account_name)        AS account_name,
    a.account_full_name,
    a.classification,
    a.account_type,
    a.account_sub_type,
    COALESCE(a.classification IN ('Revenue', 'Expense'), FALSE) AS is_profit_and_loss,
    l.debit,
    l.credit,
    l.debit - l.credit                              AS net_debit,
    CASE
        WHEN a.classification IN ('Asset', 'Expense') THEN l.debit - l.credit
        ELSE l.credit - l.debit
    END                                             AS amount_natural
FROM lines l
-- The header is unique per transaction id and number in staging, and accounts are
-- unique per id, so neither join can multiply lines.
LEFT JOIN {{staging.quickbooks.journal_report}} h
    ON  h.quickbooks_company = l.quickbooks_company
    AND h.transaction_id     = l.transaction_id
    AND h.transaction_number = l.transaction_number
LEFT JOIN {{staging.quickbooks.account}} a
    ON  a.quickbooks_company = l.quickbooks_company
    AND a.account_id         = l.account_id
