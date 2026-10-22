-- core_harvest__project_budget
-- Budget, spend and profitability per project, all time.
-- Grain: project.
--
-- Two kinds of numbers sit side by side:
--   budget_* columns come from Harvest's Project Budget report, in the unit of
--     budget_by (hours or money) and, for monthly budgets, for the current month.
--   everything else is summed from time entries, expenses and invoices over the
--     project's whole life.
-- revenue is the fixed fee for fixed-fee projects and billable time plus billable
-- expenses otherwise, in the client's currency. cost is time cost (account
-- currency) plus all expenses (client currency); when the two currencies differ,
-- profit is not meaningful and is left NULL.

WITH time_totals AS (
    SELECT
        project_id,
        SUM(rounded_hours)                                                    AS hours,
        SUM(IF(is_billable, rounded_hours, 0))                                AS billable_hours,
        SUM(IF(is_billable, rounded_hours * COALESCE(billable_rate, 0), 0))   AS billable_amount,
        SUM(hours * COALESCE(cost_rate, 0))                                   AS time_cost,
        MIN(spent_date)                                                       AS first_entry_date,
        MAX(spent_date)                                                       AS last_entry_date
    FROM {{ ref('stg_harvest__time_entry') }}
    GROUP BY 1
),

expense_totals AS (
    SELECT
        project_id,
        SUM(total_cost)                          AS expenses,
        SUM(IF(is_billable, total_cost, 0))      AS billable_expenses
    FROM {{ ref('stg_harvest__expense') }}
    GROUP BY 1
),

invoiced AS (
    SELECT
        l.project_id,
        SUM(l.amount) AS invoiced_amount
    FROM {{ ref('stg_harvest__invoice_line_item') }} l
    JOIN {{ ref('stg_harvest__invoice') }} i USING (invoice_id)
    WHERE i.state IN ('open', 'paid')
      AND l.project_id IS NOT NULL
    GROUP BY 1
)

SELECT
    p.project_id,
    p.project_name,
    p.project_code,
    p.client_id,
    p.client_name,
    p.client_currency,
    c.currency                                                   AS account_currency,
    p.is_active,
    p.is_billable,
    p.is_fixed_fee,
    p.bill_by,
    p.starts_on,
    p.ends_on,
    COALESCE(b.budget_by, p.budget_by)                           AS budget_by,
    COALESCE(b.budget_is_monthly, p.budget_is_monthly)           AS budget_is_monthly,
    b.budget,
    b.budget_spent,
    b.budget_remaining,
    SAFE_DIVIDE(b.budget_spent, b.budget)                        AS budget_used_pct,
    ROUND(COALESCE(t.hours, 0), 2)                               AS hours,
    ROUND(COALESCE(t.billable_hours, 0), 2)                      AS billable_hours,
    ROUND(COALESCE(t.billable_amount, 0), 2)                     AS billable_amount,
    ROUND(COALESCE(t.time_cost, 0), 2)                           AS time_cost,
    ROUND(COALESCE(e.expenses, 0), 2)                            AS expenses,
    ROUND(COALESCE(e.billable_expenses, 0), 2)                   AS billable_expenses,
    ROUND(COALESCE(inv.invoiced_amount, 0), 2)                   AS invoiced_amount,
    ROUND(IF(p.is_fixed_fee, p.fee,
             COALESCE(t.billable_amount, 0) + COALESCE(e.billable_expenses, 0)), 2) AS revenue,
    ROUND(IF(p.client_currency = c.currency,
             IF(p.is_fixed_fee, p.fee, COALESCE(t.billable_amount, 0) + COALESCE(e.billable_expenses, 0))
             - COALESCE(t.time_cost, 0) - COALESCE(e.expenses, 0),
             NULL), 2)                                           AS profit,
    t.first_entry_date,
    t.last_entry_date
FROM {{ ref('stg_harvest__project') }} p
CROSS JOIN {{ ref('stg_harvest__company') }} c
LEFT JOIN {{ ref('stg_harvest__project_budget_report') }} b USING (project_id)
LEFT JOIN time_totals t USING (project_id)
LEFT JOIN expense_totals e USING (project_id)
LEFT JOIN invoiced inv USING (project_id)
