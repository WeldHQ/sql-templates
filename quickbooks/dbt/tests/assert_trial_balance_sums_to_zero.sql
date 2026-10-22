-- Total debits equal total credits in every month's trial balance, both on the
-- cumulative balances and on the report-style balances that move prior years'
-- income and expense into retained earnings.
--
-- If assert_transactions_balance passes and this fails, the spine or the fiscal
-- year logic in core_quickbooks__trial_balance is wrong rather than the data.

SELECT
    quickbooks_company,
    month,
    SUM(closing_net_debit)       AS cumulative_total,
    SUM(trial_balance_net_debit) AS report_total
FROM {{ ref('core_quickbooks__trial_balance') }}
GROUP BY 1, 2
HAVING ABS(SUM(closing_net_debit)) > 0.01
    OR ABS(SUM(trial_balance_net_debit)) > 0.01
