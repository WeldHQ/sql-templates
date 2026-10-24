-- staging.workday_financial_management.company
-- Companies, for the name and the base currency that ledger amounts are in.
--
-- Grain: one row per company.
--
-- Single tenant. To add another, UNION ALL a second block below pointing at that
-- tenant's connector with a different workday_tenant label.

SELECT
    'tenant_1'                                              AS workday_tenant,
    CAST(id AS STRING)                                      AS company_id,
    CAST(descriptor AS STRING)                              AS company_name,
    CAST(organization_data_organization_code AS STRING)     AS company_code,
    UPPER(CAST(accounting_data_currency_code AS STRING))    AS company_currency
FROM {{raw.workday_financial_management.company}}
