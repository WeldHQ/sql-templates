-- stg_netsuite__account_type
-- NetSuite's account types (Bank, AcctRec, Income, COGS, Expense, ...): whether
-- the type belongs on the balance sheet, and which side is its normal balance.
--
-- Grain: one row per account type code.
--
-- is_debit_normal comes from the `left` flag: TRUE for types whose balance sits on
-- the debit (left) side, i.e. assets and expenses.

SELECT
    'account_1'                          AS netsuite_account,
    CAST(id AS STRING)                   AS account_type_id,
    CAST(longname AS STRING)             AS account_type_name,
    CAST(`left` AS BOOL)                 AS is_debit_normal,
    CAST(balancesheet AS BOOL)           AS is_balance_sheet,
    CAST(seqnum AS INT64)                AS report_order
FROM {{ source('netsuite', 'accounttype') }}
