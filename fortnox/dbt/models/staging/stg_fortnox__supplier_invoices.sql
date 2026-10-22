-- stg_fortnox__supplier_invoices
-- Thin wrapper over raw `supplier_invoices`: one row per supplier invoice
-- (leverantörsfaktura). `given_number` is Fortnox's own running number and the key;
-- `invoice_number` is the supplier's number and is not unique across suppliers.
--
-- Money columns are in the invoice's own currency; the `_sek` columns convert with the
-- booked rate, amount * currency_rate / currency_unit.

SELECT
    CAST(given_number AS STRING)                             AS given_number,
    invoice_number                                           AS supplier_invoice_number,
    CAST(supplier_number AS STRING)                          AS supplier_number,
    supplier_name,
    CAST(invoice_date AS DATE)                               AS invoice_date,
    CAST(due_date AS DATE)                                   AS due_date,
    CAST(final_pay_date AS DATE)                             AS final_pay_date,
    currency,
    CAST(COALESCE(currency_rate, 1) AS NUMERIC)              AS currency_rate,
    CAST(COALESCE(NULLIF(currency_unit, 0), 1) AS NUMERIC)   AS currency_unit,
    CAST(total AS NUMERIC)                                   AS total,
    CAST(vat AS NUMERIC)                                     AS total_vat,
    CAST(balance AS NUMERIC)                                 AS balance,
    CAST(balance AS NUMERIC) * CAST(COALESCE(currency_rate, 1) AS NUMERIC)
        / CAST(COALESCE(NULLIF(currency_unit, 0), 1) AS NUMERIC) AS balance_sek,
    CAST(total AS NUMERIC) * CAST(COALESCE(currency_rate, 1) AS NUMERIC)
        / CAST(COALESCE(NULLIF(currency_unit, 0), 1) AS NUMERIC) AS total_sek,
    COALESCE(booked, FALSE)                                  AS is_booked,
    COALESCE(cancelled, FALSE)                               AS is_cancelled,
    COALESCE(credit, FALSE)                                  AS is_credit,
    COALESCE(payment_pending, FALSE)                         AS is_payment_pending
FROM {{ source('fortnox', 'supplier_invoices') }}
WHERE given_number IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY given_number ORDER BY _weld_synced DESC) = 1
