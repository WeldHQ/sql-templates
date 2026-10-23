-- core.google_play.earnings_monthly
-- What Google Play charged, kept and refunded per app and product, by month: the
-- Earnings report in Play Console, reduced to the lines finance needs.
--
-- Grain: one row per transaction month (Pacific Time) x package x product (SKU) x
-- merchant currency.
-- Depends on: staging.google_play.earnings
--
-- Every bucket is a plain SUM of Google's signed amounts in your payout currency,
-- and net_earnings is the sum of all lines. That is why net_earnings ties to the
-- payout: nothing is re-signed or ABS()-ed on the way. Lines whose type is not one
-- of the named buckets (rebills, adjustments, new types Google adds) are in
-- other_amounts; watch that column rather than assuming it stays zero.
--
-- This will not match the revenue chart in Play Console. That chart is built from
-- the estimated sales report, in buyer currencies, before withholding tax and
-- chargebacks. Earnings are what Google actually pays out; reconcile to the payout.

SELECT
    DATE_TRUNC(transaction_date, MONTH)                                     AS month_start,
    package_name,
    sku_id,
    ANY_VALUE(product_title)                                                AS product_title,
    ANY_VALUE(product_type)                                                 AS product_type,
    merchant_currency,

    -- Orders, not lines: description holds the order ID, and a renewal gets its own.
    COUNT(DISTINCT IF(transaction_type = 'Charge', description, NULL))      AS charged_orders,
    COUNT(DISTINCT IF(transaction_type = 'Charge refund', description, NULL)) AS refunded_orders,
    SUM(IF(transaction_type = 'Charge', amount_merchant_currency, 0))       AS gross_charges,
    SUM(IF(transaction_type = 'Charge refund', amount_merchant_currency, 0)) AS charge_refunds,
    SUM(IF(transaction_type = 'Google fee', amount_merchant_currency, 0))   AS google_fees,
    SUM(IF(transaction_type = 'Google fee refund', amount_merchant_currency, 0)) AS google_fee_refunds,
    SUM(IF(transaction_type IN ('Tax', 'Tax refund'), amount_merchant_currency, 0)) AS taxes,
    SUM(IF(transaction_type NOT IN ('Charge', 'Charge refund', 'Google fee',
                                    'Google fee refund', 'Tax', 'Tax refund')
           OR transaction_type IS NULL, amount_merchant_currency, 0))      AS other_amounts,
    SUM(amount_merchant_currency)                                           AS net_earnings,

    -- Google's effective cut of what buyers paid, after refunds on both sides.
    ROUND(SAFE_DIVIDE(
        -1 * SUM(IF(transaction_type IN ('Google fee', 'Google fee refund'), amount_merchant_currency, 0)),
        NULLIF(SUM(IF(transaction_type IN ('Charge', 'Charge refund'), amount_merchant_currency, 0)), 0)
    ), 4)                                                                   AS effective_fee_rate
FROM {{staging.google_play.earnings}}
GROUP BY month_start, package_name, sku_id, merchant_currency
