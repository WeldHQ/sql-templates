-- staging.fortnox.financial_years
-- Thin wrapper over raw `financial_years`: one row per Fortnox financial year
-- (räkenskapsår). Many Swedish companies run a broken fiscal year, so a financial
-- year is not a calendar year; everything that groups by year uses this table.

SELECT
    CAST(id AS INT64)                 AS financial_year_id,
    CAST(from_date AS DATE)           AS financial_year_start,
    CAST(to_date AS DATE)             AS financial_year_end,
    account_chart_type,
    -- ACCRUAL (fakturametoden) or CASH (kontantmetoden). Under the cash method,
    -- customer and supplier invoices only reach the ledger when they are paid.
    accounting_method
FROM {{raw.fortnox.financial_years}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
