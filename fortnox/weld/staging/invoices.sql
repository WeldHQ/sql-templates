-- staging.fortnox.invoices
-- Thin wrapper over raw `invoices`: one row per customer invoice (kundfaktura).
--
-- Money columns are in the invoice's own currency (`currency`). Fortnox gives the rate
-- used at booking as `currency_rate` per `currency_unit` units, so the SEK value is
-- amount * currency_rate / currency_unit. For SEK invoices the rate is 1. The `_sek`
-- columns apply that rate; they are the booked value, not a revaluation at today's rate.
--
-- Credit invoices (`is_credit`) carry negative totals and balances.

SELECT
    CAST(document_number AS INT64)                           AS invoice_number,
    CAST(customer_number AS STRING)                          AS customer_number,
    customer_name,
    CAST(invoice_date AS DATE)                               AS invoice_date,
    CAST(due_date AS DATE)                                   AS due_date,
    CAST(final_pay_date AS DATE)                             AS final_pay_date,
    currency,
    CAST(COALESCE(currency_rate, 1) AS NUMERIC)              AS currency_rate,
    CAST(COALESCE(NULLIF(currency_unit, 0), 1) AS NUMERIC)   AS currency_unit,
    CAST(total AS NUMERIC)                                   AS total,
    CAST(total_vat AS NUMERIC)                               AS total_vat,
    CAST(balance AS NUMERIC)                                 AS balance,
    CAST(balance AS NUMERIC) * CAST(COALESCE(currency_rate, 1) AS NUMERIC)
        / CAST(COALESCE(NULLIF(currency_unit, 0), 1) AS NUMERIC) AS balance_sek,
    CAST(total AS NUMERIC) * CAST(COALESCE(currency_rate, 1) AS NUMERIC)
        / CAST(COALESCE(NULLIF(currency_unit, 0), 1) AS NUMERIC) AS total_sek,
    COALESCE(booked, FALSE)                                  AS is_booked,
    COALESCE(cancelled, FALSE)                               AS is_cancelled,
    COALESCE(credit, FALSE)                                  AS is_credit,
    COALESCE(sent, FALSE)                                    AS is_sent,
    invoice_type,
    terms_of_payment,
    CAST(voucher_year AS INT64)                              AS financial_year_id,
    voucher_series,
    CAST(voucher_number AS INT64)                            AS voucher_number
FROM {{raw.fortnox.invoices}}
WHERE document_number IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY document_number ORDER BY _weld_synced DESC) = 1
