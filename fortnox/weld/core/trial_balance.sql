-- core.fortnox.trial_balance
-- Trial balance per financial year (saldobalans): opening balance, the year's debits
-- and credits, and closing balance for every account.
--
-- Grain: one row per financial year x account.
-- Currency: SEK. Sign: debit positive, credit negative, so the closing balances of all
-- accounts in a year sum to zero.
--
-- The opening balance comes from Fortnox itself (`balance_brought_forward` on the
-- account for that year): it is zero for income statement accounts and carries the
-- prior year's closing balance for balance sheet accounts once Fortnox has rolled the
-- year over. `closing_balance` is computed here as opening + movement;
-- `closing_balance_fortnox` is Fortnox's own figure, and `closing_balance_difference`
-- should be zero (see tests/assert_fortnox__trial_balance_ties_to_fortnox.sql).
--
-- An account appears if it is in the chart for that year or has postings in it, so
-- accounts with a balance and no movement are not lost.

WITH movements AS (
    SELECT
        financial_year_id,
        account_number,
        SUM(debit)  AS period_debit,
        SUM(credit) AS period_credit,
        SUM(amount) AS period_movement
    FROM {{core.fortnox.general_ledger}}
    GROUP BY 1, 2
),

accounts_and_movements AS (
    SELECT
        COALESCE(a.financial_year_id, m.financial_year_id) AS financial_year_id,
        COALESCE(a.account_number, m.account_number)       AS account_number,
        a.account_name,
        a.is_active,
        COALESCE(a.opening_balance, 0)                     AS opening_balance,
        COALESCE(m.period_debit, 0)                        AS period_debit,
        COALESCE(m.period_credit, 0)                       AS period_credit,
        COALESCE(m.period_movement, 0)                     AS period_movement,
        a.closing_balance_fortnox
    FROM {{staging.fortnox.accounts}} a
    FULL OUTER JOIN movements m
      ON m.financial_year_id = a.financial_year_id
     AND m.account_number    = a.account_number
)

SELECT
    x.financial_year_id,
    fy.financial_year_start,
    fy.financial_year_end,
    x.account_number,
    x.account_name,
    x.is_active,
    g.statement,
    g.report_line,
    g.sort_order                                        AS report_line_sort_order,
    x.opening_balance,
    x.period_debit,
    x.period_credit,
    x.period_movement,
    x.opening_balance + x.period_movement               AS closing_balance,
    x.closing_balance_fortnox,
    x.opening_balance + x.period_movement
        - x.closing_balance_fortnox                     AS closing_balance_difference
FROM accounts_and_movements x
LEFT JOIN {{staging.fortnox.financial_years}} fy
       ON fy.financial_year_id = x.financial_year_id
LEFT JOIN {{staging.fortnox.bas_account_groups}} g
       ON x.account_number BETWEEN g.range_start AND g.range_end
-- Drop chart entries that never carried a balance or a posting in that year.
WHERE x.opening_balance <> 0
   OR x.period_debit <> 0
   OR x.period_credit <> 0
   OR COALESCE(x.closing_balance_fortnox, 0) <> 0
