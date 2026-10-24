-- core_klarna__fees_by_type
-- What Klarna charged, broken down by fee type, per month, with the effective
-- rate against that month's sales.
-- Grain: month x klarna_account x merchant_id x currency_code x transaction_type
--        x detailed_type.
-- Currency: the transaction's own. Never sum across currency_code.
-- Depends on: staging.klarna.transaction
--
-- Covers the cost side of the ledger: FEE, TAX (the VAT Klarna charges on its
-- fees), FEE_REFUND and CHARGE. detailed_type is what makes this useful: it splits
-- FEE into the percentage purchase fee, the fixed per-order fee, return fees,
-- extra invoice fees and so on, which is how a merchant checks the bill against
-- the contracted rate.
--
-- fee_rate_of_sales divides this row's cost by ALL of the month's sales for the
-- same account, merchant and currency: a ratio of sums, so summing fee_amount over
-- a month and dividing by monthly_sales gives the same answer as summing the
-- rates. Do not average fee_rate_of_sales across rows; add them.
--
-- Month follows the same date rule as daily_settlement_activity: sale_date,
-- falling back to capture_date, in UTC.

WITH txn AS (
    SELECT
        *,
        DATE_TRUNC(DATE(COALESCE(sale_at, capture_at)), MONTH) AS activity_month
    FROM {{ ref('stg_klarna__transaction') }}
    WHERE COALESCE(sale_at, capture_at) IS NOT NULL
),

monthly_sales AS (
    SELECT
        klarna_account,
        merchant_id,
        currency_code,
        activity_month,
        SUM(ABS(amount)) AS monthly_sales
    FROM txn
    WHERE transaction_type = 'SALE'
    GROUP BY 1, 2, 3, 4
),

costs AS (
    SELECT
        klarna_account,
        merchant_id,
        currency_code,
        activity_month,
        transaction_type,
        COALESCE(detailed_type, '(none)')  AS detailed_type,
        COUNT(*)                           AS transactions,
        COUNT(DISTINCT order_id)           AS orders,
        -- Cost is positive, refunds of cost negative, so the column sums to net cost.
        SUM(CASE WHEN transaction_type = 'FEE_REFUND' THEN -ABS(amount) ELSE ABS(amount) END) AS fee_amount
    FROM txn
    WHERE transaction_type IN ('FEE', 'TAX', 'FEE_REFUND', 'CHARGE')
    GROUP BY 1, 2, 3, 4, 5, 6
)

SELECT
    c.activity_month,
    c.klarna_account,
    c.merchant_id,
    c.currency_code,
    c.transaction_type,
    c.detailed_type,
    c.transactions,
    c.orders,
    c.fee_amount,
    COALESCE(m.monthly_sales, 0)                AS monthly_sales,
    SAFE_DIVIDE(c.fee_amount, m.monthly_sales)  AS fee_rate_of_sales
FROM costs c
LEFT JOIN monthly_sales m
    ON  m.klarna_account = c.klarna_account
    AND m.merchant_id    = c.merchant_id
    AND m.currency_code  IS NOT DISTINCT FROM c.currency_code
    AND m.activity_month = c.activity_month
