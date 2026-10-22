-- core.fortnox.general_ledger
-- The general ledger (huvudbok): every booked voucher row with its voucher, account and
-- financial year. Recreates the transaction list behind Fortnox's Huvudbok report.
--
-- Grain: one row per voucher row (financial year x voucher series x voucher number x
-- row index). Struck-through (removed) rows are excluded, so the ledger sums to zero
-- per voucher and in total.
--
-- Currency: SEK, the accounting currency of every Fortnox company.
-- Sign: `amount` is debit minus credit. Assets and expenses are positive, liabilities,
-- equity and revenue negative. `amount_credit_positive` flips it for revenue-style
-- reading.
--
-- Dates: `transaction_date` is the voucher's bookkeeping date (bokföringsdatum).
-- Vouchers are dated in their own financial year, so posting month and financial year
-- always agree.

SELECT
    r.financial_year_id,
    fy.financial_year_start,
    fy.financial_year_end,
    v.transaction_date,
    DATE_TRUNC(v.transaction_date, MONTH)        AS transaction_month,
    r.voucher_series,
    r.voucher_number,
    CONCAT(r.voucher_series, ' ', CAST(r.voucher_number AS STRING)) AS voucher_id,
    r.row_index,
    v.voucher_description,
    r.row_description,
    r.transaction_information,
    r.account_number,
    a.account_name,
    g.statement,
    g.report_line,
    g.sort_order                                  AS report_line_sort_order,
    r.debit,
    r.credit,
    r.amount,
    -1 * r.amount                                 AS amount_credit_positive,
    r.quantity,
    COALESCE(r.cost_center, v.voucher_cost_center) AS cost_center,
    COALESCE(r.project, v.voucher_project)         AS project,
    v.reference_type,
    v.reference_number,
    v.approval_state
FROM {{staging.fortnox.voucher_rows}} r
LEFT JOIN {{staging.fortnox.vouchers}} v
       ON v.financial_year_id = r.financial_year_id
      AND v.voucher_series    = r.voucher_series
      AND v.voucher_number    = r.voucher_number
LEFT JOIN {{staging.fortnox.accounts}} a
       ON a.financial_year_id = r.financial_year_id
      AND a.account_number    = r.account_number
LEFT JOIN {{staging.fortnox.financial_years}} fy
       ON fy.financial_year_id = r.financial_year_id
-- Ranges do not overlap, so this join adds at most one group per row.
LEFT JOIN {{staging.fortnox.bas_account_groups}} g
       ON r.account_number BETWEEN g.range_start AND g.range_end
WHERE NOT r.is_removed
