-- The daily report holds every dated transaction exactly once.
--
-- Sales and total fee cost summed over daily_settlement_activity must equal the
-- same sums taken straight from the transaction ledger. A gap means the spine
-- join dropped or duplicated days, typically after adding a dimension to the
-- grain on one side of the join and not the other.

WITH ledger AS (
    SELECT
        klarna_account,
        merchant_id,
        currency_code,
        SUM(IF(transaction_type = 'SALE', ABS(amount), 0)) AS sales,
        SUM(CASE
                WHEN transaction_type IN ('FEE', 'TAX') THEN ABS(amount)
                WHEN transaction_type = 'FEE_REFUND' THEN -ABS(amount)
                ELSE 0
            END) AS total_fee_cost
    FROM {{ ref('stg_klarna__transaction') }}
    WHERE COALESCE(sale_at, capture_at) IS NOT NULL
    GROUP BY 1, 2, 3
),

daily AS (
    SELECT
        klarna_account,
        merchant_id,
        currency_code,
        SUM(sales)          AS sales,
        SUM(total_fee_cost) AS total_fee_cost
    FROM {{ ref('core_klarna__daily_settlement_activity') }}
    GROUP BY 1, 2, 3
)

SELECT
    l.klarna_account,
    l.merchant_id,
    l.currency_code,
    l.sales,
    d.sales AS daily_sales,
    l.total_fee_cost,
    d.total_fee_cost AS daily_total_fee_cost
FROM ledger l
LEFT JOIN daily d
    ON  d.klarna_account = l.klarna_account
    AND d.merchant_id    = l.merchant_id
    AND d.currency_code  IS NOT DISTINCT FROM l.currency_code
WHERE ABS(l.sales - COALESCE(d.sales, 0)) > 0.01
   OR ABS(l.total_fee_cost - COALESCE(d.total_fee_cost, 0)) > 0.01
