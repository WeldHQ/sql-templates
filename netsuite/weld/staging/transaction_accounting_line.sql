-- staging.netsuite.transaction_accounting_line
-- NetSuite's general ledger impact: one row per transaction line per accounting
-- book, with the account it posts to and the debit or credit. This is the table
-- NetSuite's own financial reports are built from.
--
-- Grain: transaction x transaction line x accounting book.
--
-- Currency: amounts are in the base currency of the line's subsidiary, in that
-- accounting book. A multi-subsidiary account therefore holds several currencies
-- in this one table; never sum across subsidiaries without converting.
--
-- debit and credit are both positive. posting is FALSE for lines of non-posting
-- transactions (sales orders, estimates, purchase orders); core filters them out.
--
-- Single NetSuite account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different netsuite_account label.

SELECT
    'account_1'                          AS netsuite_account,
    CAST(transaction AS STRING)          AS transaction_id,
    CAST(transactionline AS STRING)      AS transaction_line_id,
    CAST(accountingbook AS STRING)       AS accounting_book_id,
    CAST(account AS STRING)              AS account_id,
    COALESCE(CAST(debit AS NUMERIC), 0)  AS debit,
    COALESCE(CAST(credit AS NUMERIC), 0) AS credit,
    CAST(amountunpaid AS NUMERIC)        AS amount_unpaid,
    CAST(exchangerate AS NUMERIC)        AS exchange_rate,
    COALESCE(CAST(posting AS BOOL), FALSE) AS is_posting
FROM {{raw.netsuite.transactionaccountingline}}
