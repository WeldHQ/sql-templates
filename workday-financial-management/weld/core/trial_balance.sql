-- core.workday_financial_management.trial_balance
-- Month-end balance per ledger account, per company, ledger and book code, built
-- from posted journal lines.
--
-- Grain: company x ledger x book code x account set x ledger account x month,
-- from the first month with a posting to the current month (or the last posted
-- month, if later), so balances carry through months without activity.
--
-- Book code: journals without one apply to every book; journals with one only to
-- that book. For the balance of one book, add the NULL book code rows to that
-- book's rows. For the primary view, filter to book_code IS NULL.
--
-- Currency: the company's base currency (company_currency).
--
-- Columns, debit-positive (debit - credit):
--   period_debit, period_credit, period_net_debit   activity in the month
--   closing_net_debit         cumulative since the first posted journal
--   closing_balance_natural   the same, signed by the account's normal balance
--
-- Months are calendar months of the accounting date. Workday's Trial Balance
-- reports by fiscal period and shows income and expense accounts for the fiscal
-- year to date; the fiscal schedule is not part of these tables, so compare
-- balance sheet accounts here and income and expense accounts through
-- profit_and_loss_by_month.
--
-- Only journals synced since the connection's start date are included. If the
-- sync does not reach back to the first journal, closing balances are missing the
-- opening balance and only period amounts can be trusted.

WITH monthly AS (
    SELECT
        workday_tenant,
        company_id,
        ledger_id,
        book_code,
        account_set_code,
        ledger_account_code,
        accounting_month  AS month,
        SUM(ledger_debit)  AS period_debit,
        SUM(ledger_credit) AS period_credit
    FROM {{core.workday_financial_management.general_ledger}}
    WHERE accounting_month IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),

bounds AS (
    SELECT
        workday_tenant,
        company_id,
        ledger_id,
        book_code,
        account_set_code,
        ledger_account_code,
        MIN(month) AS first_month,
        GREATEST(
            MAX(MAX(month)) OVER (PARTITION BY workday_tenant),
            DATE_TRUNC(CURRENT_DATE(), MONTH)
        )          AS last_month
    FROM monthly
    GROUP BY 1, 2, 3, 4, 5, 6
),

spine AS (
    SELECT
        b.workday_tenant,
        b.company_id,
        b.ledger_id,
        b.book_code,
        b.account_set_code,
        b.ledger_account_code,
        month
    FROM bounds b,
        UNNEST(GENERATE_DATE_ARRAY(b.first_month, b.last_month, INTERVAL 1 MONTH)) AS month
),

filled AS (
    SELECT
        s.*,
        COALESCE(m.period_debit, 0)                                AS period_debit,
        COALESCE(m.period_credit, 0)                               AS period_credit,
        COALESCE(m.period_debit, 0) - COALESCE(m.period_credit, 0) AS period_net_debit
    FROM spine s
    LEFT JOIN monthly m
        ON  m.workday_tenant      = s.workday_tenant
        AND m.company_id          IS NOT DISTINCT FROM s.company_id
        AND m.ledger_id           IS NOT DISTINCT FROM s.ledger_id
        AND m.book_code           IS NOT DISTINCT FROM s.book_code
        AND m.account_set_code    IS NOT DISTINCT FROM s.account_set_code
        AND m.ledger_account_code IS NOT DISTINCT FROM s.ledger_account_code
        AND m.month               = s.month
),

balances AS (
    SELECT
        *,
        SUM(period_net_debit) OVER (
            PARTITION BY workday_tenant, company_id, ledger_id, book_code,
                         account_set_code, ledger_account_code
            ORDER BY month
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS closing_net_debit
    FROM filled
)

SELECT
    b.workday_tenant,
    b.company_id,
    c.company_name,
    c.company_currency,
    b.ledger_id,
    b.book_code,
    b.month,
    b.account_set_code,
    b.ledger_account_code,
    la.ledger_account_name,
    la.ledger_account_type,
    la.classification,
    COALESCE(la.classification IN ('Revenue', 'Expense'), FALSE) AS is_profit_and_loss,
    b.period_debit,
    b.period_credit,
    b.period_net_debit,
    b.closing_net_debit,
    IF(la.classification IN ('Liability', 'Equity', 'Revenue'), -b.closing_net_debit, b.closing_net_debit) AS closing_balance_natural
FROM balances b
LEFT JOIN {{staging.workday_financial_management.account_set}} s
    ON  s.workday_tenant   = b.workday_tenant
    AND s.account_set_code = b.account_set_code
LEFT JOIN {{staging.workday_financial_management.ledger_account}} la
    ON  la.workday_tenant      = b.workday_tenant
    AND la.account_set_wid     = s.account_set_wid
    AND la.ledger_account_code = b.ledger_account_code
LEFT JOIN {{staging.workday_financial_management.company}} c
    ON  c.workday_tenant = b.workday_tenant
    AND c.company_id     = b.company_id
