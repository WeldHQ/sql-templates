-- core.fortnox.profit_and_loss_by_month
-- Income statement by month (resultaträkning per månad), at account level with the BAS
-- report line alongside so it can be rolled up to the statutory layout in BI.
--
-- Grain: one row per financial year x month x account, income statement accounts only
-- (BAS 3000-8989).
-- Currency: SEK.
-- Sign: `amount` is credit positive, the way an income statement reads: revenue is
-- positive, costs are negative, and SUM(amount) over all lines is the result for the
-- period. `debit` and `credit` are kept for audit.
--
-- Excluded: 8990-8999, the year-end transfer of the result to equity. Including it
-- would make the closing month of every year sum to zero. Summed over a month or year,
-- this model gives the result before that transfer, which is what Fortnox's
-- Resultaträkning report shows.

SELECT
    financial_year_id,
    financial_year_start,
    transaction_month                       AS month,
    report_line,
    report_line_sort_order,
    account_number,
    account_name,
    SUM(debit)                              AS debit,
    SUM(credit)                             AS credit,
    SUM(amount_credit_positive)             AS amount,
    COUNT(*)                                AS voucher_rows
FROM {{core.fortnox.general_ledger}}
WHERE statement = 'income_statement'
GROUP BY 1, 2, 3, 4, 5, 6, 7
