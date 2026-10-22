-- core.netsuite.general_ledger
-- Every posting NetSuite made to the general ledger, one row per accounting line,
-- with the account, its type and the line's subsidiary and dimensions.
--
-- Grain: transaction x transaction line x accounting book. Keep
-- accounting_book_id in every GROUP BY: an account with Multi-Book Accounting
-- posts the same transaction once per book, and summing across books counts it
-- twice. Without Multi-Book there is only the primary book.
--
-- Currency: the base currency of the line's subsidiary, in that book. Every
-- aggregate downstream keeps subsidiary_id in its grain for that reason.
--
-- Included: posting lines of posting transactions that have not been deleted.
-- Statistical and non-posting account types carry no money and are left out.
--
-- Signs:
--   debit, credit     both positive, as NetSuite stores them
--   net_debit         debit - credit; sums to zero per transaction, book and
--                     subsidiary
--   amount_natural    signed by the account type's normal balance: debit - credit
--                     for debit-normal types (assets, expenses), credit - debit
--                     for the rest. Positive means the account grew.

WITH live_transactions AS (
    SELECT t.*
    FROM {{staging.netsuite.transaction}} t
    LEFT JOIN {{staging.netsuite.deleted_record}} d
        ON  d.netsuite_account = t.netsuite_account
        AND d.record_type      = t.record_type
        AND d.record_id        = t.transaction_id
    WHERE d.record_id IS NULL
      AND t.is_posting
)

SELECT
    tal.netsuite_account,
    tal.accounting_book_id,
    tl.subsidiary_id,
    t.transaction_date,
    DATE_TRUNC(t.transaction_date, MONTH)        AS transaction_month,
    t.posting_period_id,
    t.transaction_type,
    t.record_type,
    tal.transaction_id,
    t.document_number,
    tal.transaction_line_id,
    COALESCE(tl.line_memo, t.memo)               AS memo,
    tl.entity_id,
    tl.department_id,
    tl.class_id,
    tl.location_id,
    tal.account_id,
    a.account_number,
    a.account_name,
    a.account_type_id,
    at.account_type_name,
    COALESCE(NOT at.is_balance_sheet, FALSE)     AS is_profit_and_loss,
    tal.debit,
    tal.credit,
    tal.debit - tal.credit                       AS net_debit,
    IF(COALESCE(at.is_debit_normal, TRUE), tal.debit - tal.credit, tal.credit - tal.debit) AS amount_natural
FROM {{staging.netsuite.transaction_accounting_line}} tal
-- Header: one row per transaction id. Line: one row per transaction and line id.
-- Account and account type: one row per id. None of the joins can add rows.
JOIN live_transactions t
    ON  t.netsuite_account = tal.netsuite_account
    AND t.transaction_id   = tal.transaction_id
LEFT JOIN {{staging.netsuite.transaction_line}} tl
    ON  tl.netsuite_account    = tal.netsuite_account
    AND tl.transaction_id      = tal.transaction_id
    AND tl.transaction_line_id = tal.transaction_line_id
LEFT JOIN {{staging.netsuite.account}} a
    ON  a.netsuite_account = tal.netsuite_account
    AND a.account_id       = tal.account_id
LEFT JOIN {{staging.netsuite.account_type}} at
    ON  at.netsuite_account = a.netsuite_account
    AND at.account_type_id  = a.account_type_id
WHERE tal.is_posting
  AND tal.account_id IS NOT NULL
  AND COALESCE(a.account_type_id, '') NOT IN ('Stat', 'NonPosting')
