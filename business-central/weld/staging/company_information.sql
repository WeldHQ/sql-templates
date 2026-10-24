-- staging.business_central.company_information
-- Thin wrapper over raw `company_information`: one row per company, with its local
-- currency (LCY) and the start of its current fiscal year.

SELECT
    company_id,
    display_name                                         AS company_name,
    NULLIF(TRIM(currency_code), '')                      AS local_currency_code,
    SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(current_fiscal_year_start_date, 1, 10)) AS current_fiscal_year_start,
    country
FROM {{raw.business_central.company_information}}
WHERE company_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY company_id ORDER BY _weld_synced DESC) = 1
