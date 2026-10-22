-- stg_quickbooks__account
-- The chart of accounts. classification is QuickBooks' top-level class (Asset,
-- Liability, Equity, Revenue, Expense) and decides the account's normal balance;
-- account_type is the finer type (Bank, Accounts Receivable, Income, Cost of Goods
-- Sold, Other Expense, ...) and decides where it sits on the P&L.
--
-- Grain: one row per account.
--
-- Single company. To add another, UNION ALL a second block below pointing at that
-- company's connector with a different quickbooks_company label.

SELECT
    'company_1'                                AS quickbooks_company,
    CAST(id AS STRING)                         AS account_id,
    CAST(name AS STRING)                       AS account_name,
    CAST(fully_qualified_name AS STRING)       AS account_full_name,
    CAST(classification AS STRING)             AS classification,
    CAST(account_type AS STRING)               AS account_type,
    CAST(account_sub_type AS STRING)           AS account_sub_type,
    UPPER(CAST(currency_ref_value AS STRING))  AS account_currency,
    COALESCE(CAST(sub_account AS BOOL), FALSE) AS is_sub_account,
    COALESCE(CAST(active AS BOOL), TRUE)       AS is_active
FROM {{ source('quickbooks', 'account') }}
