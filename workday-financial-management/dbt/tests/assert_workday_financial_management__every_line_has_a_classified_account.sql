-- Every ledger account that received a posting resolves to an account and a
-- classification.
--
-- Rows here are accounts that are missing from the ledger_account table or whose
-- type the keyword mapping in stg_workday_financial_management__ledger_account
-- does not recognise. They count as debit-normal balance sheet accounts until
-- fixed, so they are left out of the P&L.

SELECT
    workday_tenant,
    account_set_code,
    ledger_account_code,
    ANY_VALUE(ledger_account_name) AS ledger_account_name,
    ANY_VALUE(ledger_account_type) AS ledger_account_type,
    COUNT(*)                       AS lines
FROM {{ ref('core_workday_financial_management__general_ledger') }}
WHERE classification IS NULL
GROUP BY 1, 2, 3
