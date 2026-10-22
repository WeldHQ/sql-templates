-- staging.netvisor.finnish_account_groups
-- Static map from account number ranges to report lines. No raw source.
--
-- Netvisor does not sync the chart of accounts, so account names and types are not
-- available; the account number is the only structure. The ranges below follow the
-- four-digit layout most Finnish charts are built on: 1 assets, 2 equity and
-- liabilities, 3 to 9 the income statement in the order of the statutory layout
-- (kululajikohtainen tuloslaskelma). Charts are company specific, so CHECK THESE RANGES
-- AGAINST YOUR OWN CHART (Netvisor: Kirjanpito, Tilikartta) before relying on the
-- grouping. Every core model reads its grouping from this one place.

SELECT * FROM UNNEST([
    STRUCT(1000 AS range_start, 1999 AS range_end, 'balance_sheet' AS statement, 'assets' AS report_line, 10 AS sort_order),
    STRUCT(2000, 2999, 'balance_sheet', 'equity_and_liabilities', 20),
    STRUCT(3000, 3999, 'income_statement', 'net_sales', 30),
    STRUCT(4000, 4999, 'income_statement', 'materials_and_services', 40),
    STRUCT(5000, 6799, 'income_statement', 'personnel_expenses', 50),
    STRUCT(6800, 6999, 'income_statement', 'depreciation_and_impairment', 60),
    STRUCT(7000, 8999, 'income_statement', 'other_operating_expenses', 70),
    STRUCT(9000, 9799, 'income_statement', 'financial_items', 80),
    STRUCT(9800, 9899, 'income_statement', 'appropriations', 90),
    STRUCT(9900, 9999, 'income_statement', 'income_taxes', 100)
])
