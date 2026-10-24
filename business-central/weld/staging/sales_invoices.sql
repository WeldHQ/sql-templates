-- staging.business_central.sales_invoices
-- Thin wrapper over raw `sales_invoice`: one row per sales invoice, per company.
--
-- Money columns are in the invoice's own currency. Business Central leaves
-- `currency_code` blank when the invoice is in the company's local currency; it stays
-- NULL here and core fills it from company_information. `remaining_amount` is what the
-- customer still owes on this invoice, including tax.

SELECT
    company_id,
    id                                                   AS invoice_id,
    number                                               AS invoice_number,
    external_document_number,
    SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(invoice_date, 1, 10)) AS invoice_date,
    SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(posting_date, 1, 10)) AS posting_date,
    SAFE.PARSE_DATE('%Y-%m-%d', SUBSTR(due_date, 1, 10))     AS due_date,
    customer_id,
    customer_number,
    customer_name,
    NULLIF(TRIM(currency_code), '')                      AS currency_code,
    CAST(total_amount_excluding_tax AS NUMERIC)          AS total_amount_excluding_tax,
    CAST(total_amount_including_tax AS NUMERIC)          AS total_amount_including_tax,
    CAST(remaining_amount AS NUMERIC)                    AS remaining_amount,
    status
FROM {{raw.business_central.sales_invoice}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY company_id, id
    ORDER BY last_modified_date_time DESC, _weld_synced DESC
) = 1
