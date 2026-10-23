-- Every settled transaction points at a payout that was synced.
--
-- The connector reads transactions payout by payout, so an orphan means the
-- payout stream and the transaction stream were synced over different windows,
-- or only one of them is enabled. Orphaned transactions still show up in
-- daily_settlement_activity but are invisible to payout_reconciliation, so the
-- two reports stop agreeing.

SELECT
    t.klarna_account,
    t.merchant_id,
    t.payment_reference,
    COUNT(*) AS orphaned_transactions
FROM {{ ref('stg_klarna__transaction') }} t
LEFT JOIN {{ ref('stg_klarna__payout') }} p
    ON  p.klarna_account    = t.klarna_account
    AND p.merchant_id       = t.merchant_id
    AND p.payment_reference = t.payment_reference
WHERE p.payment_reference IS NULL
GROUP BY 1, 2, 3
