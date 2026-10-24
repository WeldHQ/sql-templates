-- staging.daisycon.financial_invoice
-- Thin wrapper over raw `financial_invoices`, the invoices Daisycon sends the
-- advertiser. Casts, parses the date strings, keeps the latest row per invoice.
-- Grain: one row per advertiser x invoice.
--
-- Dates arrive as strings; the first ten characters are parsed as a date and
-- anything unparseable becomes NULL. Amounts are in currency_code.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(advertiser_id AS STRING)                          AS advertiser_id,
        CAST(invoice_number AS STRING)                         AS invoice_number,
        SAFE_CAST(LEFT(CAST(date AS STRING), 10) AS DATE)       AS invoice_date,
        SAFE_CAST(LEFT(CAST(date_due AS STRING), 10) AS DATE)   AS due_date,
        SAFE_CAST(LEFT(CAST(date_paid AS STRING), 10) AS DATE)  AS paid_date,
        SAFE_CAST(LEFT(CAST(start_date AS STRING), 10) AS DATE) AS period_start_date,
        SAFE_CAST(LEFT(CAST(end_date AS STRING), 10) AS DATE)   AS period_end_date,
        CAST(status AS STRING)                                 AS invoice_status,
        UPPER(CAST(currency_code AS STRING))                   AS currency,
        CAST(amount_excl_vat AS NUMERIC)                       AS amount_excl_vat,
        CAST(vat AS NUMERIC)                                   AS vat,
        CAST(amount AS NUMERIC)                                AS amount_incl_vat,
        ROW_NUMBER() OVER (PARTITION BY advertiser_id, invoice_number ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.daisycon.financial_invoices}}
)
WHERE row_rank = 1
