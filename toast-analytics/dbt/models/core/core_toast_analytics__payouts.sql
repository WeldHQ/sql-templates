-- core_toast_analytics__payouts
-- Toast card payouts per settlement date: card payments, refunds, processing fees,
-- withholdings and what landed in the bank, with the effective fee rate.
-- Grain: settled date x restaurant.
--
-- Use this to reconcile Toast deposits on your bank statement. The effective fee
-- rate is fees over payments on the row; over a period, sum both and divide.

SELECT
    settled_date,
    restaurant_id,
    restaurant_name,
    payout_status,
    sales_period_start_at,
    sales_period_end_at,
    transactions,
    payment_amount,
    refund_amount,
    fee_amount,
    withholding_amount,
    payout_amount,
    SAFE_DIVIDE(ABS(fee_amount), payment_amount)   AS effective_fee_rate
FROM {{ ref('stg_toast_analytics__payout') }}
