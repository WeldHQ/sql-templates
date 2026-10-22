-- stg_business_central__accounts
-- Thin wrapper over raw `account`: the chart of accounts, one row per G/L account per
-- company.
--
-- `category` is Business Central's account category (Assets, Liabilities, Equity,
-- Income, Cost of Goods Sold, Expense). It is normalised here to a lower-case token
-- without spaces, and mapped to the statement the account belongs to: the first three
-- are balance sheet, the last three income statement. This is the same split Business
-- Central's Income/Balance field makes.
--
-- `account_type` distinguishes Posting accounts from Heading, Total, Begin-Total and
-- End-Total lines. Only Posting accounts carry entries.

SELECT
    company_id,
    id                                                   AS account_id,
    number                                               AS account_number,
    display_name                                         AS account_name,
    LOWER(REPLACE(TRIM(category), ' ', ''))              AS account_category,
    sub_category                                         AS account_subcategory,
    CASE LOWER(REPLACE(TRIM(category), ' ', ''))
        WHEN 'assets'          THEN 'balance_sheet'
        WHEN 'liabilities'     THEN 'balance_sheet'
        WHEN 'equity'          THEN 'balance_sheet'
        WHEN 'income'          THEN 'income_statement'
        WHEN 'costofgoodssold' THEN 'income_statement'
        WHEN 'expense'         THEN 'income_statement'
        ELSE 'unclassified'
    END                                                  AS statement,
    account_type,
    blocked                                              AS is_blocked,
    direct_posting                                       AS allows_direct_posting
FROM {{ source('business_central', 'account') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY company_id, id
    ORDER BY last_modified_date_time DESC, _weld_synced DESC
) = 1
