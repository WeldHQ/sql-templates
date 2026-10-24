-- Every ledger line resolves to an account with a class (Asset, Liability, Equity,
-- Revenue, Expense).
--
-- The class decides whether a line lands in the P&L or on the balance sheet. A line
-- without one is silently treated as a balance sheet credit-normal account. That
-- happens when the account is missing from the account stream, or when QuickBooks
-- returns an account type that staging does not map to a class yet.

SELECT
    quickbooks_company,
    account_id,
    ANY_VALUE(account_name) AS account_name,
    ANY_VALUE(account_type) AS account_type,
    COUNT(*)                AS lines
FROM {{ ref('core_quickbooks__general_ledger') }}
WHERE classification IS NULL
GROUP BY 1, 2
