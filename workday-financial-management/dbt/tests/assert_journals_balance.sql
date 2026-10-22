-- Every posted journal balances per company in ledger currency.
--
-- Workday will not post an unbalanced journal, so a failure means lines were lost
-- or left behind on the way: most often a journal edited after it was synced
-- whose old lines are still in the line table, or ledger amounts missing on some
-- lines so the fallback to transaction amounts mixed currencies.
--
-- One cent of tolerance for rounding.

SELECT
    workday_tenant,
    journal_entry_id,
    company_id,
    SUM(net_debit) AS difference
FROM {{ ref('core_workday_financial_management__general_ledger') }}
GROUP BY 1, 2, 3
HAVING ABS(SUM(net_debit)) > 0.01
