-- staging.fortnox.vouchers
-- Thin wrapper over raw `vouchers`: one row per voucher (verifikation). A voucher is
-- identified by series, number and financial year together; voucher A 15 exists once
-- in every financial year.

SELECT
    CAST(year AS INT64)                  AS financial_year_id,
    voucher_series,
    CAST(voucher_number AS INT64)        AS voucher_number,
    CAST(transaction_date AS DATE)       AS transaction_date,
    description                          AS voucher_description,
    comments                             AS voucher_comments,
    reference_type,
    reference_number,
    cost_center                          AS voucher_cost_center,
    project                              AS voucher_project,
    CAST(approval_state AS INT64)        AS approval_state
FROM {{raw.fortnox.vouchers}}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY year, voucher_series, voucher_number
    ORDER BY _weld_synced DESC
) = 1
