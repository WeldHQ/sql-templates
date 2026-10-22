-- stg_fortnox__voucher_rows
-- Thin wrapper over raw `voucher_rows`: one row per line on a voucher. This is the
-- general ledger: every booked amount in Fortnox is a voucher row.
--
-- Amounts are SEK. Fortnox stores debit and credit as two non-negative columns;
-- `amount` here is debit minus credit, so debits are positive, credits negative and
-- every voucher sums to zero.
--
-- Removed rows are kept and flagged. When a voucher is corrected in Fortnox the
-- original row is struck through (Removed) and a replacement row is added; the struck
-- row is still returned by the API but does not count towards any balance. Core models
-- filter on `is_removed = FALSE`.

SELECT
    CAST(voucher_year AS INT64)                              AS financial_year_id,
    voucher_series,
    CAST(voucher_number AS INT64)                            AS voucher_number,
    CAST(`index` AS INT64)                                   AS row_index,
    CAST(account AS INT64)                                   AS account_number,
    CAST(COALESCE(debit, 0) AS NUMERIC)                      AS debit,
    CAST(COALESCE(credit, 0) AS NUMERIC)                     AS credit,
    CAST(COALESCE(debit, 0) AS NUMERIC)
        - CAST(COALESCE(credit, 0) AS NUMERIC)               AS amount,
    CAST(quantity AS NUMERIC)                                AS quantity,
    description                                              AS row_description,
    transaction_information,
    cost_center,
    project,
    COALESCE(removed, FALSE)                                 AS is_removed
FROM {{ source('fortnox', 'voucher_rows') }}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY voucher_year, voucher_series, voucher_number, `index`
    ORDER BY _weld_synced DESC
) = 1
