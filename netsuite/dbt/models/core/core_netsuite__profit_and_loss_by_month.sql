-- core_netsuite__profit_and_loss_by_month
-- NetSuite's Income Statement by month and account, built from the general
-- ledger.
--
-- Grain: accounting book x subsidiary x month x account, income statement account
-- types only, months with postings only.
--
-- Currency: the subsidiary's base currency. Keep subsidiary_id in the grain of
-- any rollup, or translate to one currency first.
--
-- Signs:
--   amount            as the report prints it: income positive on income accounts,
--                     expenses positive on expense accounts
--   net_income_impact credit - debit: income positive, expenses negative. A plain
--                     SUM over rows is their contribution to net income, so Gross
--                     Profit is the sum over the Income and Cost of Goods Sold
--                     sections and Net Income the sum over everything.
--
-- Months are calendar months of the transaction date; see trial_balance.sql for
-- how that differs from NetSuite's posting periods.

SELECT
    netsuite_account,
    accounting_book_id,
    subsidiary_id,
    transaction_month                      AS month,
    account_id,
    ANY_VALUE(account_number)              AS account_number,
    ANY_VALUE(account_name)                AS account_name,
    ANY_VALUE(account_type_id)             AS account_type_id,
    ANY_VALUE(account_type_name)           AS account_type_name,
    CASE ANY_VALUE(account_type_id)
        WHEN 'Income'     THEN 'Income'
        WHEN 'COGS'       THEN 'Cost of Goods Sold'
        WHEN 'Expense'    THEN 'Expenses'
        WHEN 'OthIncome'  THEN 'Other Income'
        WHEN 'OthExpense' THEN 'Other Expenses'
        ELSE 'Other'
    END                                    AS section,
    CASE ANY_VALUE(account_type_id)
        WHEN 'Income'     THEN 1
        WHEN 'COGS'       THEN 2
        WHEN 'Expense'    THEN 3
        WHEN 'OthIncome'  THEN 4
        WHEN 'OthExpense' THEN 5
        ELSE 6
    END                                    AS section_order,
    SUM(debit)                             AS debit,
    SUM(credit)                            AS credit,
    SUM(amount_natural)                    AS amount,
    SUM(credit - debit)                    AS net_income_impact
FROM {{ ref('core_netsuite__general_ledger') }}
WHERE is_profit_and_loss
  AND transaction_month IS NOT NULL
GROUP BY netsuite_account, accounting_book_id, subsidiary_id, transaction_month, account_id
