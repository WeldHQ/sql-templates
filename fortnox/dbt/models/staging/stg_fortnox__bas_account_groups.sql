-- stg_fortnox__bas_account_groups
-- Static map from BAS account number ranges to report lines. No raw source.
--
-- Fortnox companies almost all use the Swedish BAS chart of accounts, where the first
-- digit is the account class: 1 assets, 2 equity and liabilities, 3 to 8 the income
-- statement. The ranges below follow the BAS layout of the Swedish statutory income
-- statement (kostnadsslagsindelad resultaträkning). If your chart deviates, edit the
-- ranges here; every core model reads its grouping from this one place.
--
-- 8990-8999 is where the year's result is booked against equity (8999 Årets resultat
-- against 2099) when a year is closed. Including it would zero the income statement for
-- that month, so it is flagged and the P&L excludes it.

SELECT * FROM UNNEST([
    STRUCT(1000 AS range_start, 1999 AS range_end, 'balance_sheet' AS statement, 'assets' AS report_line, 10 AS sort_order),
    STRUCT(2000, 2999, 'balance_sheet', 'equity_and_liabilities', 20),
    STRUCT(3000, 3799, 'income_statement', 'net_sales', 30),
    STRUCT(3800, 3999, 'income_statement', 'other_operating_income', 40),
    STRUCT(4000, 4999, 'income_statement', 'goods_and_materials', 50),
    STRUCT(5000, 6999, 'income_statement', 'other_external_expenses', 60),
    STRUCT(7000, 7699, 'income_statement', 'personnel_expenses', 70),
    STRUCT(7700, 7899, 'income_statement', 'depreciation_and_write_downs', 80),
    STRUCT(7900, 7999, 'income_statement', 'other_operating_expenses', 90),
    STRUCT(8000, 8799, 'income_statement', 'financial_items', 100),
    STRUCT(8800, 8899, 'income_statement', 'appropriations', 110),
    STRUCT(8900, 8989, 'income_statement', 'income_tax', 120),
    STRUCT(8990, 8999, 'year_end_transfer', 'result_for_the_year', 130)
])
