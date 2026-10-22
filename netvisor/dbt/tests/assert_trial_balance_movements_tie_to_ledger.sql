-- The monthly trial balance must carry exactly the ledger's movements: per month, the
-- sum of period movements across accounts equals the ledger total for that month, and
-- both are zero. Catches a broken month spine, a fan-out in the account map, or ledger
-- lines without a parsable date.

WITH ledger AS (
    SELECT voucher_month AS month, SUM(amount) AS ledger_total, COUNT(*) AS ledger_lines
    FROM {{ ref('core_netvisor__general_ledger') }}
    GROUP BY 1
),

trial_balance AS (
    SELECT month, SUM(period_movement) AS tb_total
    FROM {{ ref('core_netvisor__trial_balance_by_month') }}
    GROUP BY 1
)

SELECT
    l.month,
    l.ledger_total,
    t.tb_total
FROM ledger l
LEFT JOIN trial_balance t USING (month)
WHERE l.month IS NULL
   OR t.tb_total IS NULL
   OR ABS(l.ledger_total - t.tb_total) > 0.01
   OR ABS(l.ledger_total) > 0.01
