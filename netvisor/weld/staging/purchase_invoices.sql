-- staging.netvisor.purchase_invoices
-- Thin wrapper over raw `purchase_invoice`: one row per purchase invoice (ostolasku).
--
-- `amount` is the invoice total and `paid_amount` what has been paid against it, so
-- `open_amount` is what is still owed. Netvisor's purchase invoice payload carries no
-- currency code; amounts are treated as the company's accounting currency (EUR). If you
-- book foreign-currency purchase invoices, check a few against Netvisor before trusting
-- the totals.

SELECT
    netvisor_key                                              AS purchase_invoice_key,
    purchase_invoice_number,
    CAST(purchase_invoice_date_value AS DATE)                 AS invoice_date,
    CAST(purchase_invoice_due_date_value AS DATE)             AS due_date,
    CAST(purchase_invoice_amount AS NUMERIC)                  AS amount,
    CAST(COALESCE(purchase_invoice_paid_amount, 0) AS NUMERIC) AS paid_amount,
    CAST(purchase_invoice_amount AS NUMERIC)
        - CAST(COALESCE(purchase_invoice_paid_amount, 0) AS NUMERIC) AS open_amount,
    LOWER(invoice_status)                                     AS invoice_status,
    LOWER(approval_status)                                    AS approval_status,
    is_accounted,
    vendor_netvisor_key                                       AS vendor_key,
    CAST(vendor_code AS STRING)                               AS vendor_code,
    vendor_name,
    vendor_organization_identifier                            AS vendor_business_id,
    purchase_invoice_reference_number                         AS reference_number
FROM {{raw.netvisor.purchase_invoice}}
WHERE netvisor_key IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY netvisor_key ORDER BY _weld_synced DESC) = 1
