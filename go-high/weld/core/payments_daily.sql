-- core.go_high.payments_daily
-- Money taken through HighLevel Payments per day: the Transactions view in Payments,
-- summed. Amount, refunds, net, and how many customers paid.
--
-- Grain: one row per day (UTC, transaction created) x location x currency x source type x
-- status.
-- Depends on: staging.go_high.transaction
--
-- Status is part of the grain rather than filtered here, because HighLevel's status
-- values differ by payment provider and are not fully documented. For collected money,
-- filter to the statuses that mean a successful charge in your account (typically
-- `succeeded`, plus the refunded states, since a refunded payment was collected first).
-- Failed and pending rows carry an amount that was never collected.
--
-- Refunds are dated on the original payment, not the day the refund happened, because
-- the transaction carries no refund date. Net for recent days falls as refunds arrive.
-- Test-mode payments are excluded. Currencies are never mixed in a row.

SELECT
    DATE(created_at)                                            AS date,
    location_id,
    currency,
    COALESCE(source_type, '(none)')                             AS source_type,
    status,

    COUNT(*)                                                    AS transactions,
    COUNT(DISTINCT contact_id)                                  AS contacts,
    COUNTIF(subscription_id IS NOT NULL)                        AS subscription_transactions,
    SUM(amount)                                                 AS amount,
    SUM(amount_refunded)                                        AS refunded_amount,
    SUM(amount - amount_refunded)                               AS net_amount
FROM {{staging.go_high.transaction}}
WHERE is_live IS NOT FALSE
  AND created_at IS NOT NULL
GROUP BY 1, 2, 3, 4, 5
