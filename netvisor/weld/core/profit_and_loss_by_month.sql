-- core.netvisor.profit_and_loss_by_month
-- Income statement by month (tuloslaskelma kuukausittain), at account level with the
-- report line alongside so it can be rolled up in BI.
--
-- Grain: one row per month x account, income statement accounts only (3000-9999 in the
-- default ranges of staging.netvisor.finnish_account_groups).
-- Currency: the company's accounting currency (EUR).
-- Sign: `amount` is credit positive, the way an income statement reads: revenue is
-- positive, costs negative, and SUM(amount) over all lines is the result for the
-- period. `debit` and `credit` are kept for audit.
--
-- Months are calendar months of the voucher date. Fiscal-year totals are a sum over the
-- months of your fiscal year.

SELECT
    voucher_month                          AS month,
    report_line,
    report_line_sort_order,
    account_number,
    SUM(debit)                             AS debit,
    SUM(credit)                            AS credit,
    SUM(amount_credit_positive)            AS amount,
    COUNT(*)                               AS voucher_lines
FROM {{core.netvisor.general_ledger}}
WHERE statement = 'income_statement'
GROUP BY 1, 2, 3, 4
