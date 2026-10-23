-- core.walmart.settlement_ledger
-- What Walmart actually paid you: the settlement reconciliation file turned into
-- a ledger, one row per order line and transaction type per payout.
--
-- Grain: settlement date x seller x posted date x purchase order x purchase
-- order line x SKU x transaction type. Lines that belong to no order (advertising,
-- WFS storage, account adjustments) keep NULL order and SKU columns rather than
-- being dropped; they are real deductions from the deposit.
--
-- WHY THIS EXISTS. core.walmart.sales_over_time says what customers ordered.
-- Between that and the deposit sit Walmart's commission (its referral fee), WFS
-- fulfilment and storage fees, advertising, return shipping charges and
-- adjustments. None of them is on the order. This is also the only model where
-- refunds land on the day the money moved (posted_date).
--
-- SIGNS ARE WALMART'S. Sales positive, commission, fees and refunds negative.
-- net_payable is a plain SUM(amount), and summed over a settlement date it should
-- equal the file's total_payable, the amount deposited
-- (dbt/tests/assert_walmart__settlement_ties_to_deposits.sql).
--
-- A refund is identified by transaction_type, not by a negative amount: fees are
-- negative too. Refund lines also reverse commission (Walmart returns its
-- referral fee on a refund), and that reversal stays in the commission column.
--
-- unclassified_amount and other_amount should be small. Walmart adds amount
-- types without notice; when it does, the money is still in net_payable but in
-- no named column.
--
-- Depends on: staging.walmart.recon_report

SELECT
    settlement_date,
    walmart_seller,
    posted_date,
    currency,
    purchase_order_id,
    purchase_order_line,
    customer_order_id,
    sku,
    transaction_type,
    ANY_VALUE(product_name)                                                              AS product_name,
    ANY_VALUE(fulfillment_type)                                                          AS fulfillment_type,
    SUM(CASE WHEN ledger_category = 'product' THEN ship_qty END)                         AS ship_qty,

    ROUND(SUM(CASE WHEN ledger_category = 'product'  AND NOT is_refund THEN amount ELSE 0 END), 2) AS product_sales,
    ROUND(SUM(CASE WHEN ledger_category = 'product'  AND is_refund     THEN amount ELSE 0 END), 2) AS product_refunds,
    ROUND(SUM(CASE WHEN ledger_category = 'shipping' THEN amount ELSE 0 END), 2)          AS shipping,
    ROUND(SUM(CASE WHEN ledger_category = 'commission' THEN amount ELSE 0 END), 2)        AS commission,
    ROUND(SUM(CASE WHEN ledger_category = 'fee_or_reimbursement' THEN amount ELSE 0 END), 2) AS fees_and_reimbursements,

    -- Sales tax Walmart collects and then withholds to remit as marketplace
    -- facilitator. Pass-through: in and back out, so it belongs in the ledger but
    -- not in margin.
    ROUND(SUM(CASE WHEN ledger_category = 'tax_collected' THEN amount ELSE 0 END), 2)     AS tax_collected,
    ROUND(SUM(CASE WHEN ledger_category = 'tax_withheld'  THEN amount ELSE 0 END), 2)     AS tax_withheld,

    ROUND(SUM(CASE WHEN ledger_category = 'other'        THEN amount ELSE 0 END), 2)      AS other_amount,
    ROUND(SUM(CASE WHEN ledger_category = 'unclassified' THEN amount ELSE 0 END), 2)      AS unclassified_amount,

    ROUND(SUM(amount), 2)                                                                 AS net_payable
FROM {{staging.walmart.recon_report}}
WHERE NOT is_summary_line
GROUP BY settlement_date, walmart_seller, posted_date, currency, purchase_order_id,
         purchase_order_line, customer_order_id, sku, transaction_type
