-- core.netvisor.trial_balance_by_month
-- Trial balance per month (saldoluettelo): for every account and month, the opening
-- balance, the month's debits and credits, and the closing balance.
--
-- Grain: one row per month x account, from the first month with a synced voucher to the
-- current month (or the latest future-dated month), including months in which an
-- account had no postings.
-- Currency: the company's accounting currency (EUR). Sign: debit positive, credit
-- negative.
--
-- How balances accumulate differs by statement:
--   balance sheet accounts (1xxx, 2xxx) accumulate over everything synced. They match
--     Netvisor only if the synced ledger reaches back to the company's first entries or
--     includes its opening balance voucher; see the README.
--   income statement accounts (3xxx-9xxx) accumulate within the fiscal year and restart
--     at its first month. Set `fiscal_year_start_month` below if your fiscal year does
--     not start in January.
-- Because prior years' results are not booked to equity in the ledger, the closing
-- balances of all accounts in a month do not sum to zero; the period movements do.

WITH settings AS (
    SELECT 1 AS fiscal_year_start_month   -- 1 = January. Change for a broken fiscal year.
),

movements AS (
    SELECT
        voucher_month                     AS month,
        account_number,
        SUM(debit)                        AS period_debit,
        SUM(credit)                       AS period_credit,
        SUM(amount)                       AS period_movement
    FROM {{core.netvisor.general_ledger}}
    WHERE voucher_month IS NOT NULL
    GROUP BY 1, 2
),

months AS (
    SELECT month
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(month) FROM movements),
        -- Run to the current month, or further if vouchers are dated ahead.
        GREATEST((SELECT MAX(month) FROM movements), DATE_TRUNC(CURRENT_DATE(), MONTH)),
        INTERVAL 1 MONTH
    )) AS month
),

accounts AS (
    SELECT DISTINCT account_number FROM movements
),

spine AS (
    SELECT
        m.month,
        a.account_number,
        g.statement,
        g.report_line,
        g.sort_order,
        -- Fiscal year labelled by the calendar year it starts in.
        EXTRACT(YEAR FROM DATE_SUB(m.month, INTERVAL (s.fiscal_year_start_month - 1) MONTH)) AS fiscal_year,
        COALESCE(mv.period_debit, 0)      AS period_debit,
        COALESCE(mv.period_credit, 0)     AS period_credit,
        COALESCE(mv.period_movement, 0)   AS period_movement
    FROM months m
    CROSS JOIN accounts a
    CROSS JOIN settings s
    LEFT JOIN movements mv
           ON mv.month = m.month
          AND mv.account_number = a.account_number
    LEFT JOIN {{staging.netvisor.finnish_account_groups}} g
           ON a.account_number BETWEEN g.range_start AND g.range_end
),

balances AS (
    SELECT
        *,
        CASE
            WHEN statement = 'income_statement' THEN
                SUM(period_movement) OVER (
                    PARTITION BY account_number, fiscal_year
                    ORDER BY month
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                )
            ELSE
                SUM(period_movement) OVER (
                    PARTITION BY account_number
                    ORDER BY month
                    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                )
        END AS closing_balance
    FROM spine
)

SELECT
    month,
    fiscal_year,
    account_number,
    statement,
    report_line,
    sort_order                                AS report_line_sort_order,
    closing_balance - period_movement         AS opening_balance,
    period_debit,
    period_credit,
    period_movement,
    closing_balance
FROM balances
