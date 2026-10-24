-- The monthly trial balance must carry exactly the ledger's movements, and its closing
-- balance in its last month must equal the sum of every entry per account. Catches a
-- broken month spine or a fan-out in the account join.

WITH ledger AS (
    SELECT company_id, account_id, SUM(amount) AS ledger_balance
    FROM {{ ref('core_business_central__general_ledger') }}
    WHERE posting_month IS NOT NULL
    GROUP BY 1, 2
),

latest AS (
    SELECT company_id, account_id, closing_balance
    FROM {{ ref('core_business_central__trial_balance_by_month') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY company_id, account_id ORDER BY month DESC) = 1
)

SELECT
    l.company_id,
    l.account_id,
    l.ledger_balance,
    t.closing_balance
FROM ledger l
LEFT JOIN latest t
       ON t.company_id = l.company_id
      AND t.account_id = l.account_id
WHERE t.closing_balance IS NULL
   OR ABS(l.ledger_balance - t.closing_balance) > 0.01
