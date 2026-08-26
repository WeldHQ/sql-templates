-- core_amazon_seller__settlement_ledger - the settlement report turned into a P&L.
--
-- Grain: settlement date x seller x marketplace x order x SKU. Currency: the
-- settlement's own.
-- Depends on: stg_amazon_seller__settlement
--
-- WHAT THIS ANSWERS THAT NOTHING ELSE CAN: how much of what a customer paid you
-- actually kept. Amazon deducts referral fees, FBA fulfilment fees, storage,
-- advertising, refund administration and a long tail of service fees before the
-- deposit lands, and none of it appears in any sales report. Sellers who model only
-- ordered_product_sales are typically surprised by 25-45% of gross - and it is not
-- a flat percentage, so you cannot approximate it with one.
--
-- HOW IT WORKS. stg_amazon_seller__settlement classifies every line into a
-- ledger_category; this model pivots those categories into columns so one row is one
-- order-SKU-day and the fee structure is readable across it. Amazon signs the report
-- itself - revenue positive, fees and refunds negative - and that convention is
-- preserved, which is the only reason the whole thing sums back to the deposit.
--
-- Every fee column is therefore NEGATIVE. net_proceeds is a sum, not a subtraction:
--     product_revenue + selling_fees + fba_fees + ...
-- Writing it with minus signs is how a fee ends up added back and margin comes out
-- above 100%.
--
-- ORDER-LEVEL LINES CARRY NO SKU. Storage fees, advertising and subscription charges
-- are charged to the account, not to a product, and arrive with sku NULL. They are
-- kept - dropping them understates cost by the entire fixed-cost base - which means
-- you cannot join this model to a SKU dimension with an INNER JOIN.
-- core_amazon_seller__asin_profitability handles the allocation.

{{ config(
    materialized='table',
    partition_by={'field': 'date', 'data_type': 'date', 'granularity': 'month'}
) }}

SELECT
    s.posted_date                                   AS date,
    s.amazon_seller,
    s.marketplace,
    s.settlement_id,
    s.amazon_order_id,
    s.sku,

    -- What the customer paid.
    ROUND(SUM(CASE WHEN s.ledger_category = 'revenue'       AND NOT s.is_refund THEN s.amount ELSE 0 END), 2) AS product_revenue,
    ROUND(SUM(CASE WHEN s.ledger_category = 'promotion'     AND NOT s.is_refund THEN s.amount ELSE 0 END), 2) AS promotions,
    ROUND(SUM(CASE WHEN s.ledger_category = 'tax_collected' AND NOT s.is_refund THEN s.amount ELSE 0 END), 2) AS tax_collected,

    -- What Amazon took. All negative.
    ROUND(SUM(CASE WHEN s.ledger_category = 'selling_fee'   THEN s.amount ELSE 0 END), 2) AS selling_fees,
    ROUND(SUM(CASE WHEN s.ledger_category = 'fba_fee'       THEN s.amount ELSE 0 END), 2) AS fba_fees,
    ROUND(SUM(CASE WHEN s.ledger_category = 'service_fee'   THEN s.amount ELSE 0 END), 2) AS service_fees,
    ROUND(SUM(CASE WHEN s.ledger_category = 'advertising'   THEN s.amount ELSE 0 END), 2) AS advertising_cost,

    -- What came back out. Refund revenue is the money returned to the customer;
    -- refunded fees are the portion Amazon gives back, which is smaller than what it
    -- charged - the referral fee is refunded, the FBA fulfilment fee generally is
    -- not. That asymmetry is why a returned unit costs more than a unit never sold.
    ROUND(SUM(CASE WHEN s.is_refund AND s.ledger_category IN ('revenue', 'promotion') THEN s.amount ELSE 0 END), 2) AS refunded_revenue,
    ROUND(SUM(CASE WHEN s.is_refund AND s.ledger_category IN ('selling_fee', 'fba_fee') THEN s.amount ELSE 0 END), 2) AS refunded_fees,
    ROUND(SUM(CASE WHEN s.ledger_category = 'reimbursement' THEN s.amount ELSE 0 END), 2) AS reimbursements,

    -- Tax Amazon collected and remitted on your behalf. Pass-through money: in and
    -- straight back out, so it belongs in the ledger but not in margin.
    ROUND(SUM(CASE WHEN s.ledger_category = 'tax_withheld'  THEN s.amount ELSE 0 END), 2) AS tax_withheld,
    ROUND(SUM(CASE WHEN s.ledger_category = 'other'         THEN s.amount ELSE 0 END), 2) AS other_amounts,

    -- Anything the classifier did not recognise. Should be zero or close to it. A
    -- non-zero total here means Amazon has introduced an amount_type since this model
    -- was written - the value is still in net_proceeds, but it is not in any named
    -- column, so watch this rather than trusting the buckets forever.
    ROUND(SUM(CASE WHEN s.ledger_category = 'unclassified'   THEN s.amount ELSE 0 END), 2) AS unclassified_amounts,

    -- The bottom line, and the reason the sign convention matters: a plain sum of
    -- every line Amazon posted is, by construction, what Amazon paid.
    ROUND(SUM(s.amount), 2)                         AS net_proceeds,

    -- Fee load as a share of product revenue. The number to trend per ASIN: Amazon
    -- adjusts fee schedules, dimensional weight bands and storage rates continuously,
    -- and a SKU that was profitable in January can quietly stop being so.
    ROUND(SAFE_DIVIDE(
        -1 * SUM(CASE WHEN s.ledger_category IN ('selling_fee', 'fba_fee', 'service_fee') THEN s.amount ELSE 0 END),
        NULLIF(SUM(CASE WHEN s.ledger_category = 'revenue' AND NOT s.is_refund THEN s.amount ELSE 0 END), 0)
    ), 4)                                           AS fee_rate_on_revenue,

    SUM(CASE WHEN s.ledger_category = 'revenue' AND NOT s.is_refund THEN s.quantity ELSE 0 END) AS units_settled,
    LOGICAL_OR(s.is_refund)                         AS has_refund,

    -- TRUE when the line has no SKU: an account-level charge such as storage,
    -- advertising or the monthly subscription. Filter on it rather than on
    -- `sku IS NULL` so the intent is legible in BI.
    s.sku IS NULL                                   AS is_account_level
FROM {{ ref('stg_amazon_seller__settlement') }} s
GROUP BY s.posted_date, s.amazon_seller, s.marketplace, s.settlement_id,
         s.amazon_order_id, s.sku
