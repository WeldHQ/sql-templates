-- core.quickbooks.profit_and_loss_by_month
-- QuickBooks' Profit and Loss report, by month and account, built from the
-- general ledger.
--
-- Grain: company x month x account, income and expense accounts only, months with
-- postings only.
--
-- Currency: the company's home currency. Month: the transaction date, on the
-- accrual basis (the Journal report is accrual; a cash-basis P&L cannot be built
-- from it).
--
-- Signs:
--   amount            as the report prints it: income positive on income
--                     accounts, expenses positive on expense accounts
--   net_income_impact credit - debit: income positive, expenses negative. A plain
--                     SUM over any set of rows is that set's contribution to net
--                     income, so Gross Profit is SUM where section is Income or
--                     Cost of Goods Sold, and Net Income is SUM over everything.
--
-- section follows the report's layout and comes from the account type. Accounts
-- whose type is not one of the five P&L types fall back to the classification.

SELECT
    quickbooks_company,
    transaction_month                                   AS month,
    account_id,
    ANY_VALUE(account_name)                             AS account_name,
    ANY_VALUE(account_full_name)                        AS account_full_name,
    ANY_VALUE(classification)                           AS classification,
    ANY_VALUE(account_type)                             AS account_type,
    CASE ANY_VALUE(account_type)
        WHEN 'Income'             THEN 'Income'
        WHEN 'Cost of Goods Sold' THEN 'Cost of Goods Sold'
        WHEN 'Expense'            THEN 'Expenses'
        WHEN 'Other Income'       THEN 'Other Income'
        WHEN 'Other Expense'      THEN 'Other Expenses'
        ELSE IF(ANY_VALUE(classification) = 'Revenue', 'Income', 'Expenses')
    END                                                 AS section,
    CASE ANY_VALUE(account_type)
        WHEN 'Income'             THEN 1
        WHEN 'Cost of Goods Sold' THEN 2
        WHEN 'Expense'            THEN 3
        WHEN 'Other Income'       THEN 4
        WHEN 'Other Expense'      THEN 5
        ELSE IF(ANY_VALUE(classification) = 'Revenue', 1, 3)
    END                                                 AS section_order,
    SUM(debit)                                          AS debit,
    SUM(credit)                                         AS credit,
    SUM(amount_natural)                                 AS amount,
    SUM(credit - debit)                                 AS net_income_impact
FROM {{core.quickbooks.general_ledger}}
WHERE is_profit_and_loss
  AND transaction_month IS NOT NULL
GROUP BY quickbooks_company, transaction_month, account_id
