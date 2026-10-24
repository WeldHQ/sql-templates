-- core.tiktok_shop.settlement_ledger
-- What TikTok actually paid you: every settlement transaction, with its revenue,
-- fees and shipping cost, on the statement it was paid in.
--
-- Grain: statement x account x shop x transaction. One statement is one payout
-- cycle for one shop; a transaction is an order, an adjustment or a reserve
-- movement. Date is the statement date in the shop's local time.
--
-- WHY THIS EXISTS. core.tiktok_shop.sales_over_time says what customers paid.
-- Between that and the payout sit platform commission, referral and transaction
-- fees, affiliate commission, shipping TikTok charged you, and adjustments, none
-- of which appear on the order. This model is the only place they are visible.
--
-- SIGNS ARE TIKTOK'S. Nothing is flipped or ABS()'d: revenue comes in positive and
-- deductions negative, and settlement_amount is TikTok's own per-transaction
-- payout. Summed over a statement it should equal the statement's
-- settlement_amount, which dbt/tests/assert_tiktok_shop__settlement_ties_to_statements.sql
-- checks. unexplained_amount shows anything the four headline components do not
-- account for; it should be zero or very close to it.
--
-- Fees are dated by statement, not by order. A May order can settle in June, so
-- do not divide one month of fees by the same month of sales and call it a fee
-- rate; compare per order (order_id is here for that) or over a long window.
--
-- Depends on: staging.tiktok_shop.statement_transaction_report, .statement, .shop

WITH shop AS (
    SELECT tiktok_account, shop_id, ANY_VALUE(report_timezone) AS report_timezone
    FROM {{staging.tiktok_shop.shop}}
    GROUP BY tiktok_account, shop_id
)

SELECT
    DATE(st.statement_at, COALESCE(s.report_timezone, 'UTC')) AS statement_date,
    t.tiktok_account,
    t.shop_id,
    t.statement_id,
    st.payment_id,
    st.payment_status,
    st.currency,
    t.transaction_id,
    t.transaction_type,
    t.order_id,
    t.adjustment_id,
    t.reserve_id,
    t.reserve_status,
    t.order_created_at,

    -- Headline components, as TikTok reports them.
    ROUND(t.revenue_amount, 2)        AS revenue,
    ROUND(t.fee_tax_amount, 2)        AS fees_and_taxes,
    ROUND(t.shipping_cost_amount, 2)  AS shipping_cost,
    ROUND(t.adjustment_amount, 2)     AS adjustments,
    ROUND(t.reserve_amount, 2)        AS reserve_amount,
    ROUND(t.settlement_amount, 2)     AS settlement_amount,

    -- Revenue detail.
    ROUND(t.subtotal_before_discount, 2)         AS subtotal_before_discount,
    ROUND(t.seller_discount, 2)                  AS seller_discount,
    ROUND(t.refund_subtotal_before_discount, 2)  AS refund_subtotal_before_discount,
    ROUND(t.seller_discount_refund, 2)           AS seller_discount_refund,

    -- Fee detail. other_fees_and_taxes is whatever fees_and_taxes holds beyond the
    -- named fees: taxes withheld and the long tail of service fees TikTok adds by
    -- region and programme. Kept visible rather than dropped.
    ROUND(t.platform_commission, 2)              AS platform_commission,
    ROUND(t.referral_fee, 2)                     AS referral_fee,
    ROUND(t.transaction_fee, 2)                  AS transaction_fee,
    ROUND(t.affiliate_commission, 2)             AS affiliate_commission,
    ROUND(t.fee_tax_amount - t.platform_commission - t.referral_fee
          - t.transaction_fee - t.affiliate_commission, 2) AS other_fees_and_taxes,

    -- Shipping detail.
    ROUND(t.actual_shipping_fee, 2)              AS actual_shipping_fee,
    ROUND(t.customer_paid_shipping_fee, 2)       AS customer_paid_shipping_fee,

    ROUND(t.settlement_amount
          - (t.revenue_amount + t.fee_tax_amount + t.shipping_cost_amount
             + t.adjustment_amount), 2)          AS unexplained_amount
FROM {{staging.tiktok_shop.statement_transaction_report}} t
LEFT JOIN {{staging.tiktok_shop.statement}} st
       ON  st.tiktok_account = t.tiktok_account
       AND st.shop_id        = t.shop_id
       AND st.statement_id   = t.statement_id
LEFT JOIN shop s
       ON  s.tiktok_account = t.tiktok_account
       AND s.shop_id        = t.shop_id
