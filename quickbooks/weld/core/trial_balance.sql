-- core.quickbooks.trial_balance
-- Month-end trial balance per account, built from the general ledger.
--
-- Grain: company x month x account, from the account's first posting to the
-- current month, so an account with no activity in a month still carries its
-- balance. Plus one synthetic row per company and month, account_id NULL, that
-- holds prior fiscal years' net income (see below).
--
-- Currency: the company's home currency.
--
-- Columns, all on the debit-positive convention (debit - credit):
--   period_debit, period_credit, period_net_debit   activity within the month
--   closing_net_debit       cumulative since the first transaction
--   fiscal_ytd_net_debit    cumulative since the start of the fiscal year, using
--                           the fiscal year start month from the company settings
--   trial_balance_net_debit what QuickBooks' Trial Balance report shows: the
--                           cumulative balance for balance sheet accounts, the
--                           fiscal year-to-date amount for income and expense
--                           accounts
--   trial_balance_debit / trial_balance_credit   the same, split into the two
--                           report columns
--
-- QuickBooks does not post a year-end closing entry. Its reports fold prior
-- fiscal years' net income into Retained Earnings on the fly. The row with
-- account_id NULL carries that amount, so trial_balance_net_debit sums to zero for
-- every company and month, the same way the report's debit and credit totals agree.
-- In the QuickBooks UI the amount is shown on the Retained Earnings line itself.

WITH company AS (
    SELECT quickbooks_company, fiscal_year_start_month
    FROM {{staging.quickbooks.company}}
),

monthly AS (
    SELECT
        quickbooks_company,
        transaction_month AS month,
        account_id,
        SUM(debit)        AS period_debit,
        SUM(credit)       AS period_credit
    FROM {{core.quickbooks.general_ledger}}
    WHERE transaction_month IS NOT NULL
    GROUP BY 1, 2, 3
),

bounds AS (
    SELECT
        m.quickbooks_company,
        m.account_id,
        MIN(m.month) AS first_month,
        -- Run to the current month, or further when transactions are post-dated.
        GREATEST(
            MAX(MAX(m.month)) OVER (PARTITION BY m.quickbooks_company),
            DATE_TRUNC(CURRENT_DATE(), MONTH)
        )            AS last_month
    FROM monthly m
    GROUP BY 1, 2
),

spine AS (
    SELECT
        b.quickbooks_company,
        b.account_id,
        month
    FROM bounds b,
        UNNEST(GENERATE_DATE_ARRAY(b.first_month, b.last_month, INTERVAL 1 MONTH)) AS month
),

accounts AS (
    SELECT
        s.quickbooks_company,
        s.month,
        DATE(
            EXTRACT(YEAR FROM s.month)
                - IF(EXTRACT(MONTH FROM s.month) < COALESCE(c.fiscal_year_start_month, 1), 1, 0),
            COALESCE(c.fiscal_year_start_month, 1),
            1
        )                                                     AS fiscal_year_start,
        s.account_id,
        a.account_name,
        a.account_full_name,
        a.classification,
        a.account_type,
        COALESCE(a.classification IN ('Revenue', 'Expense'), FALSE) AS is_profit_and_loss,
        COALESCE(m.period_debit, 0)                           AS period_debit,
        COALESCE(m.period_credit, 0)                          AS period_credit,
        COALESCE(m.period_debit, 0) - COALESCE(m.period_credit, 0) AS period_net_debit
    FROM spine s
    LEFT JOIN monthly m
        ON  m.quickbooks_company = s.quickbooks_company
        AND m.account_id         = s.account_id
        AND m.month              = s.month
    LEFT JOIN {{staging.quickbooks.account}} a
        ON  a.quickbooks_company = s.quickbooks_company
        AND a.account_id         = s.account_id
    LEFT JOIN company c
        ON  c.quickbooks_company = s.quickbooks_company
),

balances AS (
    SELECT
        *,
        SUM(period_net_debit) OVER (
            PARTITION BY quickbooks_company, account_id
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS closing_net_debit,
        SUM(period_net_debit) OVER (
            PARTITION BY quickbooks_company, account_id, fiscal_year_start
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS fiscal_ytd_net_debit
    FROM accounts
),

with_report_balance AS (
    SELECT
        quickbooks_company,
        month,
        fiscal_year_start,
        account_id,
        account_name,
        account_full_name,
        classification,
        account_type,
        is_profit_and_loss,
        period_debit,
        period_credit,
        period_net_debit,
        closing_net_debit,
        fiscal_ytd_net_debit,
        IF(is_profit_and_loss, fiscal_ytd_net_debit, closing_net_debit) AS trial_balance_net_debit
    FROM balances
),

-- Income and expense balances from earlier fiscal years: the part of their
-- cumulative balance that the year-to-date figure leaves out.
prior_years_net_income AS (
    SELECT
        quickbooks_company,
        month,
        ANY_VALUE(fiscal_year_start)                             AS fiscal_year_start,
        CAST(NULL AS STRING)                                     AS account_id,
        'Prior fiscal years net income (Retained Earnings)'      AS account_name,
        CAST(NULL AS STRING)                                     AS account_full_name,
        'Equity'                                                 AS classification,
        CAST(NULL AS STRING)                                     AS account_type,
        FALSE                                                    AS is_profit_and_loss,
        CAST(0 AS NUMERIC)                                       AS period_debit,
        CAST(0 AS NUMERIC)                                       AS period_credit,
        CAST(0 AS NUMERIC)                                       AS period_net_debit,
        CAST(0 AS NUMERIC)                                       AS closing_net_debit,
        CAST(0 AS NUMERIC)                                       AS fiscal_ytd_net_debit,
        SUM(closing_net_debit - fiscal_ytd_net_debit)            AS trial_balance_net_debit
    FROM with_report_balance
    WHERE is_profit_and_loss
    GROUP BY quickbooks_company, month
)

SELECT
    *,
    IF(trial_balance_net_debit > 0, trial_balance_net_debit, 0)  AS trial_balance_debit,
    IF(trial_balance_net_debit < 0, -trial_balance_net_debit, 0) AS trial_balance_credit
FROM (
    SELECT * FROM with_report_balance
    UNION ALL
    SELECT * FROM prior_years_net_income
)
