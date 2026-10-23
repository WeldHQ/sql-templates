-- A refund can never be larger than the payment it refunds, so net is never negative.
--
-- If this fires, HighLevel reported amount and amount_refunded in different units for a
-- provider, or a refund was recorded as its own transaction, and net totals are wrong.

SELECT transaction_id, amount, amount_refunded, status
FROM {{ ref('stg_go_high__transaction') }}
WHERE amount_refunded > amount
