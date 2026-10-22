-- stg_fortnox__accounts
-- Thin wrapper over raw `accounts`: the chart of accounts, one row per account per
-- financial year. Fortnox keeps a separate copy of the chart for every financial year,
-- each with its own opening balance (ingående balans) and closing balance (utgående
-- balans), so the key is (financial_year_id, account_number), never the account alone.
--
-- `year` on this table is the Fortnox financial year ID, not a calendar year. It joins
-- to financial_years.id and to vouchers.year.
--
-- Balances are in SEK, the accounting currency of every Fortnox company, signed debit
-- positive and credit negative: an asset carries a positive balance, a liability or
-- equity account a negative one.

SELECT
    CAST(year AS INT64)                          AS financial_year_id,
    CAST(number AS INT64)                        AS account_number,
    description                                  AS account_name,
    active                                       AS is_active,
    CAST(sru AS INT64)                           AS sru_code,
    vat_code,
    cost_center                                  AS default_cost_center,
    project                                      AS default_project,
    CAST(balance_brought_forward AS NUMERIC)     AS opening_balance,
    CAST(balance_carried_forward AS NUMERIC)     AS closing_balance_fortnox
FROM {{ source('fortnox', 'accounts') }}
WHERE number IS NOT NULL
-- The stream is incremental; keep the latest copy of each account-year.
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY year, number
    ORDER BY _weld_synced DESC
) = 1
