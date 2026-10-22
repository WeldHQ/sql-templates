-- staging.quickbooks.company
-- Company settings. Only the fiscal year start is used: it decides where the
-- year-to-date columns in core.quickbooks.trial_balance restart.
--
-- Grain: one row per company. QuickBooks returns the month as an English name
-- ("January"); it is turned into a month number here, defaulting to 1 when it is
-- missing or unrecognised.
--
-- Single company. To add another, UNION ALL a second block below pointing at that
-- company's connector with a different quickbooks_company label.

SELECT
    'company_1'                        AS quickbooks_company,
    CAST(company_name AS STRING)       AS company_name,
    CASE LOWER(TRIM(CAST(fiscal_year_start_month AS STRING)))
        WHEN 'january'   THEN 1
        WHEN 'february'  THEN 2
        WHEN 'march'     THEN 3
        WHEN 'april'     THEN 4
        WHEN 'may'       THEN 5
        WHEN 'june'      THEN 6
        WHEN 'july'      THEN 7
        WHEN 'august'    THEN 8
        WHEN 'september' THEN 9
        WHEN 'october'   THEN 10
        WHEN 'november'  THEN 11
        WHEN 'december'  THEN 12
        ELSE 1
    END                                AS fiscal_year_start_month
FROM {{raw.quickbooks.company}}
