-- stg_daisycon__financial_invoice_line
-- Thin wrapper over raw `financial_invoice_line`, the lines of each Daisycon
-- invoice. Casts, renames, keeps the latest row per line.
-- Grain: one row per advertiser x invoice x line code.
--
-- Lines carry no currency of their own; they are in the invoice's currency.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)   AS advertiser_id,
        CAST(invoice_number AS STRING)  AS invoice_number,
        CAST(code AS STRING)            AS line_code,
        CAST(description AS STRING)     AS line_description,
        CAST(quantity AS NUMERIC)       AS quantity,
        CAST(amount_excl_vat AS NUMERIC) AS amount_excl_vat,
        CAST(vat AS NUMERIC)            AS vat,
        CAST(amount AS NUMERIC)         AS amount_incl_vat,
        ROW_NUMBER() OVER (PARTITION BY advertiser_id, invoice_number, code ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('daisycon', 'financial_invoice_line') }}
)
WHERE row_rank = 1
