-- core_business_central__trial_balance_by_month
-- Trial balance per month: for every company, account and month, the opening balance,
-- the month's debits and credits, and the closing balance. Recreates Business Central's
-- Trial Balance report (net change and balance at date) for each month end.
--
-- Grain: one row per company x month x account, from the company's first posting month
-- to the current month (or the latest future-dated month), including months in which an account had no postings.
-- Currency: the company's local currency (LCY). Sign: debit positive, credit negative.
--
-- Balances accumulate over every entry synced, which is what Business Central does:
-- income statement accounts are reset only by the closing entries posted when a fiscal
-- year is closed ("Close Income Statement"), and those entries are G/L entries like any
-- other. With full history synced, closing balances of all accounts in a company sum to
-- zero every month.

WITH movements AS (
    SELECT
        company_id,
        posting_month                      AS month,
        account_id,
        SUM(debit)                         AS period_debit,
        SUM(credit)                        AS period_credit,
        SUM(amount)                        AS period_movement
    FROM {{ ref('core_business_central__general_ledger') }}
    WHERE posting_month IS NOT NULL
    GROUP BY 1, 2, 3
),

company_months AS (
    SELECT
        company_id,
        month
    FROM (
        SELECT company_id, MIN(month) AS first_month, MAX(month) AS last_month
        FROM movements
        GROUP BY 1
    ),
    UNNEST(GENERATE_DATE_ARRAY(
        first_month,
        -- Run to the current month, or further if entries are posted ahead.
        GREATEST(last_month, DATE_TRUNC(CURRENT_DATE(), MONTH)),
        INTERVAL 1 MONTH
    )) AS month
),

company_accounts AS (
    SELECT DISTINCT company_id, account_id FROM movements
),

spine AS (
    SELECT
        cm.company_id,
        cm.month,
        ca.account_id,
        COALESCE(mv.period_debit, 0)       AS period_debit,
        COALESCE(mv.period_credit, 0)      AS period_credit,
        COALESCE(mv.period_movement, 0)    AS period_movement
    FROM company_months cm
    JOIN company_accounts ca
      ON ca.company_id = cm.company_id
    LEFT JOIN movements mv
           ON mv.company_id = cm.company_id
          AND mv.month      = cm.month
          AND mv.account_id = ca.account_id
)

SELECT
    s.company_id,
    c.company_name,
    c.local_currency_code,
    s.month,
    s.account_id,
    a.account_number,
    a.account_name,
    a.account_category,
    COALESCE(a.statement, 'unclassified')  AS statement,
    SUM(s.period_movement) OVER w - s.period_movement AS opening_balance,
    s.period_debit,
    s.period_credit,
    s.period_movement,
    SUM(s.period_movement) OVER w          AS closing_balance
FROM spine s
LEFT JOIN {{ ref('stg_business_central__accounts') }} a
       ON a.company_id = s.company_id
      AND a.account_id = s.account_id
LEFT JOIN {{ ref('stg_business_central__company_information') }} c
       ON c.company_id = s.company_id
WINDOW w AS (
    PARTITION BY s.company_id, s.account_id
    ORDER BY s.month
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
