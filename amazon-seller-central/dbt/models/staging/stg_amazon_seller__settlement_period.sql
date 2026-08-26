-- stg_amazon_seller__settlement_period
-- Thin wrapper over raw `settlement_description`, the sub-table of the settlement
-- report. One row per settlement: its window, its deposit date, its total.
--
-- Small table, disproportionately useful. `total_amount` is Amazon's own figure for
-- what it paid out for the period, which makes it the one external number you can
-- check the whole ledger against - see tests/assert_settlement_ties_to_deposits.sql.
-- If the classified lines do not sum to this, the ledger is wrong, full stop.

SELECT
    'seller_1'                                                  AS amazon_seller,
    CAST(settlement_id AS STRING)                               AS settlement_id,
    CAST(settlement_start_date AS DATE)                         AS period_start_date,
    CAST(settlement_end_date AS DATE)                           AS period_end_date,
    CAST(deposit_date AS DATE)                                  AS deposit_date,
    CAST(total_amount AS NUMERIC)                               AS deposit_amount,
    UPPER(NULLIF(TRIM(CAST(currency AS STRING)), ''))           AS currency
FROM {{ source('amazon_seller_central', 'settlement_description') }}
