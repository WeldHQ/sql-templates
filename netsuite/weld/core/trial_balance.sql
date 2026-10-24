-- core.netsuite.trial_balance
-- Month-end balance per account, per subsidiary and accounting book, built from
-- the general ledger.
--
-- Grain: account x accounting book x subsidiary x month, from the first month the
-- combination has a posting to the current month (or the last posted month, if
-- later), so balances carry through months without activity.
--
-- Currency: the subsidiary's base currency. Do not sum across subsidiaries
-- without converting; for a consolidated view, translate each subsidiary with
-- NetSuite's consolidated exchange rates first.
--
-- Columns, debit-positive (debit - credit):
--   period_debit, period_credit, period_net_debit   activity within the month
--   closing_net_debit   cumulative since the first posting
--   closing_balance_natural   the same, signed by the account's normal balance
--
-- Months are calendar months of the transaction date. NetSuite reports by posting
-- period, which usually matches the transaction month but can differ when a
-- transaction is posted to an earlier or later open period. NetSuite's own Trial
-- Balance also shows income and expense accounts year-to-date and folds earlier
-- years into retained earnings, which needs the fiscal calendar; compare balance
-- sheet accounts (is_profit_and_loss = FALSE) directly, and income and expense
-- accounts through profit_and_loss_by_month.

WITH monthly AS (
    SELECT
        netsuite_account,
        accounting_book_id,
        subsidiary_id,
        account_id,
        transaction_month AS month,
        SUM(debit)        AS period_debit,
        SUM(credit)       AS period_credit
    FROM {{core.netsuite.general_ledger}}
    WHERE transaction_month IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5
),

bounds AS (
    SELECT
        netsuite_account,
        accounting_book_id,
        subsidiary_id,
        account_id,
        MIN(month) AS first_month,
        GREATEST(
            MAX(MAX(month)) OVER (PARTITION BY netsuite_account),
            DATE_TRUNC(CURRENT_DATE(), MONTH)
        )          AS last_month
    FROM monthly
    GROUP BY 1, 2, 3, 4
),

spine AS (
    SELECT
        b.netsuite_account,
        b.accounting_book_id,
        b.subsidiary_id,
        b.account_id,
        month
    FROM bounds b,
        UNNEST(GENERATE_DATE_ARRAY(b.first_month, b.last_month, INTERVAL 1 MONTH)) AS month
),

filled AS (
    SELECT
        s.netsuite_account,
        s.accounting_book_id,
        s.subsidiary_id,
        s.month,
        s.account_id,
        COALESCE(m.period_debit, 0)                                AS period_debit,
        COALESCE(m.period_credit, 0)                               AS period_credit,
        COALESCE(m.period_debit, 0) - COALESCE(m.period_credit, 0) AS period_net_debit
    FROM spine s
    LEFT JOIN monthly m
        ON  m.netsuite_account   = s.netsuite_account
        AND m.accounting_book_id IS NOT DISTINCT FROM s.accounting_book_id
        AND m.subsidiary_id      IS NOT DISTINCT FROM s.subsidiary_id
        AND m.account_id         = s.account_id
        AND m.month              = s.month
),

balances AS (
    SELECT
        *,
        SUM(period_net_debit) OVER (
            PARTITION BY netsuite_account, accounting_book_id, subsidiary_id, account_id
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS closing_net_debit
    FROM filled
)

SELECT
    b.netsuite_account,
    b.accounting_book_id,
    b.subsidiary_id,
    b.month,
    b.account_id,
    a.account_number,
    a.account_name,
    a.account_type_id,
    atype.account_type_name,
    COALESCE(NOT atype.is_balance_sheet, FALSE) AS is_profit_and_loss,
    b.period_debit,
    b.period_credit,
    b.period_net_debit,
    b.closing_net_debit,
    IF(COALESCE(atype.is_debit_normal, TRUE), b.closing_net_debit, -b.closing_net_debit) AS closing_balance_natural
FROM balances b
LEFT JOIN {{staging.netsuite.account}} a
    ON  a.netsuite_account = b.netsuite_account
    AND a.account_id       = b.account_id
LEFT JOIN {{staging.netsuite.account_type}} atype
    ON  atype.netsuite_account = a.netsuite_account
    AND atype.account_type_id  = a.account_type_id
