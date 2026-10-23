-- staging.quickbooks.account
-- The chart of accounts. classification is QuickBooks' top-level class (Asset,
-- Liability, Equity, Revenue, Expense) and decides the account's normal balance;
-- account_type is the finer type (Bank, Accounts Receivable, Income, Cost of Goods
-- Sold, Other Expense, ...) and decides where it sits on the P&L.
--
-- The API leaves classification empty on some accounts. Every account type belongs
-- to exactly one class, so an empty classification is filled in from account_type;
-- without that, an income or expense account would fall out of the P&L and be
-- treated as a balance sheet account.
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
    COALESCE(
        NULLIF(TRIM(CAST(classification AS STRING)), ''),
        CASE CAST(account_type AS STRING)
            WHEN 'Income'                  THEN 'Revenue'
            WHEN 'Other Income'            THEN 'Revenue'
            WHEN 'Cost of Goods Sold'      THEN 'Expense'
            WHEN 'Expense'                 THEN 'Expense'
            WHEN 'Other Expense'           THEN 'Expense'
            WHEN 'Equity'                  THEN 'Equity'
            WHEN 'Accounts Payable'        THEN 'Liability'
            WHEN 'Credit Card'             THEN 'Liability'
            WHEN 'Other Current Liability' THEN 'Liability'
            WHEN 'Long Term Liability'     THEN 'Liability'
            WHEN 'Accounts Receivable'     THEN 'Asset'
            WHEN 'Bank'                    THEN 'Asset'
            WHEN 'Other Current Asset'     THEN 'Asset'
            WHEN 'Fixed Asset'             THEN 'Asset'
            WHEN 'Other Asset'             THEN 'Asset'
        END
    )                                          AS classification,
    CAST(account_type AS STRING)               AS account_type,
    CAST(account_sub_type AS STRING)           AS account_sub_type,
    UPPER(CAST(currency_ref_value AS STRING))  AS account_currency,
    COALESCE(CAST(sub_account AS BOOL), FALSE) AS is_sub_account,
    COALESCE(CAST(active AS BOOL), TRUE)       AS is_active
FROM {{raw.quickbooks.account}}
