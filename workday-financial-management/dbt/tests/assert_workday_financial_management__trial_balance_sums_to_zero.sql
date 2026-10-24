-- Each company's trial balance balances in every month, per ledger and book code.
--
-- If assert_workday_financial_management__journals_balance passes and this fails, the month spine in
-- core_workday_financial_management__trial_balance is dropping or repeating rows.

SELECT
    workday_tenant,
    company_id,
    ledger_id,
    book_code,
    month,
    SUM(closing_net_debit) AS total
FROM {{ ref('core_workday_financial_management__trial_balance') }}
GROUP BY 1, 2, 3, 4, 5
HAVING ABS(SUM(closing_net_debit)) > 0.01
