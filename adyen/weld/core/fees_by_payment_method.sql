-- core.adyen.fees_by_payment_method
-- What each payment method costs: settled volume, refunds, chargebacks and the
-- transaction fees withheld, with interchange, scheme fees and markup broken out
-- where Adyen has interchange level data.
--
-- Grain: day (creation date, report time zone) x merchant account x payment method
-- x payment method variant x net (settlement) currency.
-- Depends on: staging.adyen.settlement_detail
--
-- Only transaction entries (settled, refunded, charged back) are included. Batch
-- level entries such as Adyen's own Fee lines, invoice deductions and payouts carry
-- no payment method and live in settlement_batches.
--
-- AMOUNTS are in the net currency, positive for money in and negative for money
-- out, except fee columns, where positive is a cost. settled_gross is the settled
-- amount before fees: net credit plus the fees withheld from it.
--
-- RATES. effective_fee_rate is a ratio of sums for the row. To get a rate over a
-- month or a payment method, re-aggregate transaction_fees and settled_gross and
-- divide; never average the daily rates.

SELECT
    s.created_date_local                                                          AS date,
    s.merchant_account,
    s.payment_method,
    s.payment_method_variant,
    s.net_currency,

    COUNTIF(s.entry_category = 'settled')                                         AS settled_count,
    SUM(CASE WHEN s.entry_category = 'settled' THEN s.net_amount_nc + s.transaction_fees_nc ELSE 0 END) AS settled_gross,
    SUM(CASE WHEN s.entry_category = 'settled'    THEN s.net_amount_nc ELSE 0 END) AS settled_net,
    COUNTIF(s.entry_category = 'refund')                                          AS refund_count,
    SUM(CASE WHEN s.entry_category = 'refund'     THEN s.net_amount_nc ELSE 0 END) AS refunds,
    COUNTIF(s.entry_category = 'chargeback')                                      AS chargeback_count,
    SUM(CASE WHEN s.entry_category = 'chargeback' THEN s.net_amount_nc ELSE 0 END) AS chargebacks,

    SUM(s.transaction_fees_nc)                                                    AS transaction_fees,
    SUM(COALESCE(s.interchange_nc, 0))                                            AS interchange,
    SUM(COALESCE(s.scheme_fees_nc, 0))                                            AS scheme_fees,
    SUM(COALESCE(s.markup_nc, 0))                                                 AS markup,
    SUM(COALESCE(s.commission_nc, 0))                                             AS commission,

    SUM(s.net_amount_nc)                                                          AS net_amount,

    SAFE_DIVIDE(
        SUM(s.transaction_fees_nc),
        NULLIF(SUM(CASE WHEN s.entry_category = 'settled' THEN s.net_amount_nc + s.transaction_fees_nc ELSE 0 END), 0)
    )                                                                             AS effective_fee_rate
FROM {{staging.adyen.settlement_detail}} s
WHERE s.entry_category IN ('settled', 'refund', 'chargeback')
GROUP BY 1, 2, 3, 4, 5
