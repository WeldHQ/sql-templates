-- The classified ledger must sum to the deposit Amazon says it made.
--
-- THIS IS THE MOST VALUABLE TEST IN THE SET, because it checks against a number
-- Amazon computed independently: settlement_description.total_amount is Amazon's own
-- figure for what it paid out for the period, and it appears on your bank statement.
-- If the ledger ties to it, the classification is complete and no line was dropped.
-- If it does not, no fee, margin or profitability number downstream can be trusted.
--
-- A failure has three usual causes, in order of likelihood:
--
--   1. A settlement synced only partially - check the stream's run history rather
--      than the SQL.
--   2. A filter somewhere upstream dropped lines, typically an INNER JOIN to a SKU
--      dimension that silently removed the account-level charges.
--   3. Signs were normalised. Amazon signs this report; ABS() anywhere in the chain
--      breaks the identity.
--
-- One cent of tolerance. Anything larger is real.

WITH ledger AS (
    SELECT
        settlement_id,
        SUM(net_proceeds) AS ledger_total
    FROM {{ ref('core_amazon_seller__settlement_ledger') }}
    GROUP BY 1
),

deposits AS (
    SELECT
        settlement_id,
        deposit_date,
        SUM(deposit_amount) AS deposit_total
    FROM {{ ref('stg_amazon_seller__settlement_period') }}
    GROUP BY 1, 2
)

SELECT
    d.settlement_id,
    d.deposit_date,
    d.deposit_total,
    l.ledger_total,
    ROUND(COALESCE(l.ledger_total, 0) - d.deposit_total, 2) AS diff
FROM deposits d
LEFT JOIN ledger l USING (settlement_id)
WHERE ABS(COALESCE(l.ledger_total, 0) - d.deposit_total) > 0.01
