-- The ledger must sum to the deposit Walmart says it made.
--
-- Each reconciliation file opens with a PaymentSummary line whose total_payable
-- is Walmart's own figure for the amount deposited. If the transaction lines sum
-- to it, the classification is complete and no line was dropped. Usual causes of
-- a failure:
--   1. A file that synced only partly: check the stream's run history first.
--   2. A filter or INNER JOIN upstream that removed lines with no order, such as
--      advertising or storage fees.
--   3. A sign that was flipped or an ABS() somewhere in the chain.
--
-- One cent of tolerance per settlement date.

WITH ledger AS (
    SELECT walmart_seller, settlement_date, SUM(net_payable) AS ledger_total
    FROM {{ ref('core_walmart__settlement_ledger') }}
    GROUP BY 1, 2
),

deposits AS (
    SELECT walmart_seller, settlement_date, MAX(total_payable) AS deposit_total
    FROM {{ ref('stg_walmart__recon_report') }}
    WHERE is_summary_line
    GROUP BY 1, 2
)

SELECT
    d.walmart_seller,
    d.settlement_date,
    d.deposit_total,
    l.ledger_total,
    ROUND(COALESCE(l.ledger_total, 0) - d.deposit_total, 2) AS diff
FROM deposits d
LEFT JOIN ledger l USING (walmart_seller, settlement_date)
WHERE ABS(COALESCE(l.ledger_total, 0) - d.deposit_total) > 0.01
