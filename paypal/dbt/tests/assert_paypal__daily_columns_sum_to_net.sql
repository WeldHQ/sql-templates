-- The daily summary columns must add up to the net balance change, so no record
-- falls between categories. Returns zero rows when they agree.

SELECT *
FROM {{ ref('core_paypal__daily_balance_activity') }}
WHERE ABS(
    payments_received + payments_sent + refunds + chargebacks_and_reversals
    + fees + currency_conversions + bank_deposits + bank_withdrawals
    + holds_and_releases + other
    - net_balance_change
) > 0.005
