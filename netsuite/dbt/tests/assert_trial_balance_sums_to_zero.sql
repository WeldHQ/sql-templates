-- Each subsidiary's trial balance balances in every month, per accounting book:
-- cumulative debits equal cumulative credits.
--
-- If assert_transactions_balance passes and this fails, the month spine in
-- core_netsuite__trial_balance is dropping or repeating rows.

SELECT
    netsuite_account,
    accounting_book_id,
    subsidiary_id,
    month,
    SUM(closing_net_debit) AS total
FROM {{ ref('core_netsuite__trial_balance') }}
GROUP BY 1, 2, 3, 4
HAVING ABS(SUM(closing_net_debit)) > 0.01
