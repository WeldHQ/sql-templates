-- staging.tiktok_shop.statement_transaction_report
-- Thin wrapper over raw `statement_transaction_report`: one row per transaction
-- inside a settlement statement. A transaction is an order, an adjustment or a
-- reserve movement (see `type`).
--
-- Amounts are kept with the sign TikTok gives them and are not re-derived: the
-- breakdown columns are a selection, and the four headline components plus
-- settlement_amount are TikTok's own totals. Currency is the statement's.
--
-- The connector re-reads the last week of statements because reserve status and
-- release time change after a statement closes; the latest version is kept.

SELECT
    'account_1'                                         AS tiktok_account,
    CAST(shop_id AS STRING)                             AS shop_id,
    CAST(statement_id AS STRING)                        AS statement_id,
    CAST(id AS STRING)                                  AS transaction_id,
    UPPER(CAST(type AS STRING))                         AS transaction_type,
    CAST(order_id AS STRING)                            AS order_id,
    CAST(adjustment_id AS STRING)                       AS adjustment_id,
    CAST(reserve_id AS STRING)                          AS reserve_id,
    UPPER(CAST(reserve_status AS STRING))               AS reserve_status,
    CAST(order_create_time AS TIMESTAMP)                AS order_created_at,
    CAST(estimated_release_time AS TIMESTAMP)           AS estimated_release_at,

    -- Headline components.
    COALESCE(CAST(revenue_amount AS NUMERIC), 0)        AS revenue_amount,
    COALESCE(CAST(fee_tax_amount AS NUMERIC), 0)        AS fee_tax_amount,
    COALESCE(CAST(shipping_cost_amount AS NUMERIC), 0)  AS shipping_cost_amount,
    COALESCE(CAST(adjustment_amount AS NUMERIC), 0)     AS adjustment_amount,
    COALESCE(CAST(reserve_amount AS NUMERIC), 0)        AS reserve_amount,
    COALESCE(CAST(settlement_amount AS NUMERIC), 0)     AS settlement_amount,

    -- Revenue breakdown.
    COALESCE(CAST(revenue_breakdown_subtotal_before_discount_amount AS NUMERIC), 0)        AS subtotal_before_discount,
    COALESCE(CAST(revenue_breakdown_seller_discount_amount AS NUMERIC), 0)                 AS seller_discount,
    COALESCE(CAST(revenue_breakdown_refund_subtotal_before_discount_amount AS NUMERIC), 0) AS refund_subtotal_before_discount,
    COALESCE(CAST(revenue_breakdown_seller_discount_refund_amount AS NUMERIC), 0)          AS seller_discount_refund,

    -- Fee breakdown: the fees most shops see. Everything else in fee_tax_amount
    -- is surfaced in core as other_fees_and_taxes rather than dropped.
    COALESCE(CAST(fee_tax_breakdown_fee_platform_commission_amount AS NUMERIC), 0)         AS platform_commission,
    COALESCE(CAST(fee_tax_breakdown_fee_referral_fee_amount AS NUMERIC), 0)                AS referral_fee,
    COALESCE(CAST(fee_tax_breakdown_fee_transaction_fee_amount AS NUMERIC), 0)             AS transaction_fee,
    COALESCE(CAST(fee_tax_breakdown_fee_affiliate_commission_amount AS NUMERIC), 0)
      + COALESCE(CAST(fee_tax_breakdown_fee_affiliate_partner_commission_amount AS NUMERIC), 0)
      + COALESCE(CAST(fee_tax_breakdown_fee_affiliate_ads_commission_amount AS NUMERIC), 0) AS affiliate_commission,

    -- Shipping breakdown.
    COALESCE(CAST(shipping_cost_breakdown_actual_shipping_fee_amount AS NUMERIC), 0)        AS actual_shipping_fee,
    COALESCE(CAST(shipping_cost_breakdown_customer_paid_shipping_fee_amount AS NUMERIC), 0) AS customer_paid_shipping_fee
FROM {{raw.tiktok_shop.statement_transaction_report}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, statement_id, id ORDER BY _weld_synced DESC) = 1
