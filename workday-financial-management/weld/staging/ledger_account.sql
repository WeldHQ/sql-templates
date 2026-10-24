-- staging.workday_financial_management.ledger_account
-- Ledger accounts per account set, with their type mapped to a standard
-- classification.
--
-- Grain: account set x ledger account identifier.
--
-- Workday lets each tenant define its own ledger account types, so there is no
-- fixed list to map from. classification is derived from the type's display name
-- by keyword below. Check the mapping against your tenant's types and edit the
-- CASE if a type lands in the wrong class or in NULL: classification decides the
-- normal balance and whether an account appears in the P&L.
--
-- Single tenant. To add another, UNION ALL a second block below pointing at that
-- tenant's connector with a different workday_tenant label.

SELECT
    'tenant_1'                                               AS workday_tenant,
    CAST(account_set_id AS STRING)                           AS account_set_wid,
    CAST(ledger_account_identifier AS STRING)                AS ledger_account_code,
    CAST(ledger_account_name AS STRING)                      AS ledger_account_name,
    CAST(ledger_account_type_descriptor AS STRING)           AS ledger_account_type,
    CASE
        WHEN LOWER(ledger_account_type_descriptor) LIKE '%liabilit%' THEN 'Liability'
        WHEN LOWER(ledger_account_type_descriptor) LIKE '%equity%'
          OR LOWER(ledger_account_type_descriptor) LIKE '%net asset%'
          OR LOWER(ledger_account_type_descriptor) LIKE '%net position%' THEN 'Equity'
        WHEN LOWER(ledger_account_type_descriptor) LIKE '%asset%'     THEN 'Asset'
        WHEN LOWER(ledger_account_type_descriptor) LIKE '%revenue%'
          OR LOWER(ledger_account_type_descriptor) LIKE '%income%'    THEN 'Revenue'
        WHEN LOWER(ledger_account_type_descriptor) LIKE '%expense%'
          OR LOWER(ledger_account_type_descriptor) LIKE '%cost%'      THEN 'Expense'
    END                                                      AS classification,
    COALESCE(CAST(retired AS BOOL), FALSE)                   AS is_retired
FROM {{raw.workday_financial_management.ledger_account}}
