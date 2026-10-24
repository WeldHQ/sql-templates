-- core_paypal__daily_balance_activity
-- Daily settlement summary: what moved the PayPal balance each day, by currency.
-- Recreates the totals of PayPal's balance and activity reports.
-- Grain: day (UTC) x currency. Only balance-affecting records are included.
--
-- The columns add up:
--   payments_received + payments_sent + refunds + chargebacks_and_reversals
--   + fees + currency_conversions + bank_deposits + bank_withdrawals
--   + holds_and_releases + other = net_balance_change
--
-- Payment, refund and chargeback columns are GROSS. Every fee lands in `fees`:
-- the fee charged on each record plus standalone fee records (T01). Fees are
-- negative; fees returned on refunds are positive. Refunds, chargebacks, payments
-- sent and withdrawals are negative.
--
-- Currencies are never mixed: each PayPal currency balance is its own row. Moving
-- money between them shows up as currency_conversions, negative in one currency
-- and positive in the other. Convert to a reporting currency downstream with your
-- own rates if you need one total.

SELECT
    transaction_date,
    currency,
    SUM(IF(category = 'payment_received', COALESCE(gross_amount, 0), 0))        AS payments_received,
    SUM(IF(category = 'payment_sent', COALESCE(gross_amount, 0), 0))            AS payments_sent,
    SUM(IF(category = 'refund', COALESCE(gross_amount, 0), 0))                  AS refunds,
    SUM(IF(category = 'chargeback_or_reversal', COALESCE(gross_amount, 0), 0))  AS chargebacks_and_reversals,
    SUM(fee_amount) + SUM(IF(category = 'fee', COALESCE(gross_amount, 0), 0))   AS fees,
    SUM(IF(category = 'currency_conversion', COALESCE(gross_amount, 0), 0))     AS currency_conversions,
    SUM(IF(category = 'bank_deposit', COALESCE(gross_amount, 0), 0))            AS bank_deposits,
    SUM(IF(category = 'bank_withdrawal', COALESCE(gross_amount, 0), 0))         AS bank_withdrawals,
    SUM(IF(category = 'hold_or_release', COALESCE(gross_amount, 0), 0))         AS holds_and_releases,
    SUM(IF(category = 'other', COALESCE(gross_amount, 0), 0))                   AS other,
    SUM(net_amount)                                                AS net_balance_change,
    COUNTIF(category = 'payment_received')                         AS payments_received_count,
    COUNTIF(category = 'refund')                                   AS refunds_count,
    COUNTIF(category = 'chargeback_or_reversal')                   AS chargebacks_and_reversals_count
FROM {{ ref('core_paypal__transactions') }}
WHERE is_balance_affecting
GROUP BY transaction_date, currency
