-- One row per payout, per merchant account, per connector.
--
-- Payouts are stored one row per payment_reference and merchant_id, so a
-- duplicate here means a second Klarna account was unioned into staging without
-- changing the klarna_account label, or a full resync landed beside the old table.
-- Either one doubles every settlement amount downstream.

SELECT
    klarna_account,
    merchant_id,
    payment_reference,
    COUNT(*) AS rows_for_payout
FROM {{ ref('core_klarna__payout_reconciliation') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
