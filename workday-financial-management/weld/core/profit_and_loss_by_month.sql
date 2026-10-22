-- core.workday_financial_management.profit_and_loss_by_month
-- Income statement by month and ledger account, from posted journal lines.
--
-- Grain: company x ledger x book code x account set x ledger account x month,
-- Revenue and Expense accounts only, months with postings only.
--
-- Currency: the company's base currency. Keep company_id in any rollup, or
-- translate to one currency first.
--
-- Signs:
--   amount            as an income statement prints it: revenue positive on
--                     revenue accounts, expenses positive on expense accounts
--   net_income_impact credit - debit: revenue positive, expenses negative, so a
--                     plain SUM over any rows is their contribution to net income
--
-- Which accounts count as Revenue or Expense comes from the keyword mapping in
-- staging.workday_financial_management.ledger_account. Months are calendar
-- months of the accounting date, not Workday fiscal periods.

SELECT
    workday_tenant,
    company_id,
    ANY_VALUE(company_name)                AS company_name,
    ANY_VALUE(company_currency)            AS company_currency,
    ledger_id,
    book_code,
    accounting_month                       AS month,
    account_set_code,
    ledger_account_code,
    ANY_VALUE(ledger_account_name)         AS ledger_account_name,
    ANY_VALUE(ledger_account_type)         AS ledger_account_type,
    ANY_VALUE(classification)              AS classification,
    SUM(ledger_debit)                      AS debit,
    SUM(ledger_credit)                     AS credit,
    SUM(amount_natural)                    AS amount,
    SUM(ledger_credit - ledger_debit)      AS net_income_impact
FROM {{core.workday_financial_management.general_ledger}}
WHERE is_profit_and_loss
  AND accounting_month IS NOT NULL
GROUP BY workday_tenant, company_id, ledger_id, book_code, accounting_month,
         account_set_code, ledger_account_code
