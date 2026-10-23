-- No posted line in a foreign currency arrives without ledger amounts.
--
-- Ledger amounts are what every balance is built on. When Workday leaves them
-- empty on a line in the company's base currency, the transaction amounts are the
-- same thing and are used instead. On a foreign-currency line they are not, so the
-- line is kept at 0 and flagged. Any row here means balances for that company are
-- understated; check the line in Workday and resync the journal.

SELECT
    workday_tenant,
    company_id,
    journal_entry_id,
    line_index,
    line_currency,
    company_currency,
    debit,
    credit
FROM {{ ref('core_workday_financial_management__general_ledger') }}
WHERE is_ledger_amount_missing
