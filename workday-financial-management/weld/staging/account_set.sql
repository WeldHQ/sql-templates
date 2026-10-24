-- staging.workday_financial_management.account_set
-- Account sets (charts of accounts). Only needed to translate the account set
-- code a journal line carries into the WID the ledger accounts hang off.
--
-- Grain: one row per account set.

SELECT
    'tenant_1'                                       AS workday_tenant,
    CAST(id AS STRING)                               AS account_set_wid,
    CAST(account_set_code AS STRING)                 AS account_set_code,
    CAST(account_set_name AS STRING)                 AS account_set_name
FROM {{raw.workday_financial_management.account_set}}
