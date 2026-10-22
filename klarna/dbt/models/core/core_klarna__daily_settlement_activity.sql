-- core_klarna__daily_settlement_activity
-- Sales, returns, fees and the rest of the settlement ledger, per day.
-- Grain: day x klarna_account x merchant_id x currency_code.
-- Currency: the transaction's own. Never sum across currency_code.
-- Depends on: staging.klarna.transaction
--
-- WHICH DAY A TRANSACTION LANDS ON. activity_date is sale_date, the date Klarna
-- records for the movement itself, falling back to capture_date. Both are UTC
-- timestamps and are truncated in UTC; shift them first if you report in a local
-- day. This is a transaction-date view: a sale captured on the 30th and paid out on
-- the 3rd shows on the 30th here and on the 3rd in payout_reconciliation. Expect
-- the two to disagree at any date boundary and to agree over a closed month of
-- payouts.
--
-- ONLY SETTLED MONEY. The connector reads transactions through payouts, so a sale
-- appears here once it is in a payout, not when the customer checked out. The last
-- few days are always incomplete. For order-time revenue use your shop platform.
--
-- Columns are positive amounts per type (ABS), plus net_settled_amount, the signed
-- sum of every type whose direction Klarna's API makes unambiguous. See
-- staging.klarna.transaction for the direction table.
--
-- Built on a day spine per account, merchant and currency, so a day with no
-- settled activity returns zeros instead of vanishing from a line chart.

WITH txn AS (
    SELECT
        *,
        DATE(COALESCE(sale_at, capture_at)) AS activity_date
    FROM {{ ref('stg_klarna__transaction') }}
),

series AS (
    SELECT
        klarna_account,
        merchant_id,
        currency_code,
        MIN(activity_date) AS first_date,
        MAX(activity_date) AS last_date
    FROM txn
    WHERE activity_date IS NOT NULL
    GROUP BY 1, 2, 3
),

spine AS (
    SELECT
        s.klarna_account,
        s.merchant_id,
        s.currency_code,
        d AS activity_date
    FROM series s
    CROSS JOIN UNNEST(GENERATE_DATE_ARRAY(s.first_date, s.last_date)) AS d
),

daily AS (
    SELECT
        klarna_account,
        merchant_id,
        currency_code,
        activity_date,
        COUNT(DISTINCT IF(transaction_type = 'SALE',   order_id, NULL)) AS orders_sold,
        COUNT(DISTINCT IF(transaction_type = 'RETURN', order_id, NULL)) AS orders_returned,
        SUM(IF(transaction_type = 'SALE',       ABS(amount), 0)) AS sales,
        SUM(IF(transaction_type = 'RETURN',     ABS(amount), 0)) AS returns,
        SUM(IF(transaction_type = 'FEE',        ABS(amount), 0)) AS fees,
        SUM(IF(transaction_type = 'TAX',        ABS(amount), 0)) AS tax_on_fees,
        SUM(IF(transaction_type = 'FEE_REFUND', ABS(amount), 0)) AS fee_refunds,
        SUM(IF(transaction_type = 'REVERSAL',   ABS(amount), 0)) AS reversals,
        SUM(IF(transaction_type = 'CHARGE',     ABS(amount), 0)) AS charges,
        SUM(IF(transaction_type = 'CREDIT',     ABS(amount), 0)) AS credits,
        SUM(IF(transaction_type = 'HOLDBACK',   ABS(amount), 0)) AS holdbacks,
        SUM(IF(transaction_type = 'RELEASE',    ABS(amount), 0)) AS releases,
        -- Undocumented direction: reported as Klarna sends them, kept out of net.
        SUM(IF(ledger_direction IS NULL, amount, 0))             AS undirected_amount,
        SUM(IF(ledger_direction IS NOT NULL, signed_amount, 0))  AS net_settled_amount
    FROM txn
    WHERE activity_date IS NOT NULL
    GROUP BY 1, 2, 3, 4
)

SELECT
    s.activity_date,
    s.klarna_account,
    s.merchant_id,
    s.currency_code,
    COALESCE(d.orders_sold, 0)        AS orders_sold,
    COALESCE(d.orders_returned, 0)    AS orders_returned,
    COALESCE(d.sales, 0)              AS sales,
    COALESCE(d.returns, 0)            AS returns,
    COALESCE(d.sales, 0) - COALESCE(d.returns, 0) AS net_sales,
    COALESCE(d.fees, 0)               AS fees,
    COALESCE(d.tax_on_fees, 0)        AS tax_on_fees,
    COALESCE(d.fee_refunds, 0)        AS fee_refunds,
    -- What Klarna cost you that day: fees plus the tax on them, net of refunds.
    COALESCE(d.fees, 0) + COALESCE(d.tax_on_fees, 0) - COALESCE(d.fee_refunds, 0) AS total_fee_cost,
    COALESCE(d.reversals, 0)          AS reversals,
    COALESCE(d.charges, 0)            AS charges,
    COALESCE(d.credits, 0)            AS credits,
    COALESCE(d.holdbacks, 0)          AS holdbacks,
    COALESCE(d.releases, 0)           AS releases,
    COALESCE(d.undirected_amount, 0)  AS undirected_amount,
    COALESCE(d.net_settled_amount, 0) AS net_settled_amount
FROM spine s
LEFT JOIN daily d
    ON  d.klarna_account = s.klarna_account
    AND d.merchant_id    = s.merchant_id
    AND d.currency_code  IS NOT DISTINCT FROM s.currency_code
    AND d.activity_date  = s.activity_date
