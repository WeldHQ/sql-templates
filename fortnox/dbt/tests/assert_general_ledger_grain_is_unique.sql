-- One row per voucher row. Voucher numbers repeat in every financial year and in every
-- series, so all four key parts are needed; a duplicate here means a join fanned out.

SELECT
    financial_year_id,
    voucher_series,
    voucher_number,
    row_index,
    COUNT(*) AS rows_per_key
FROM {{ ref('core_fortnox__general_ledger') }}
GROUP BY 1, 2, 3, 4
HAVING COUNT(*) > 1
