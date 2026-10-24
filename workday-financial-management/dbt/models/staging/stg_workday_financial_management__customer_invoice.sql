-- stg_workday_financial_management__customer_invoice
-- Customer invoices, header level, for the receivables aging.
--
-- Grain: one row per customer invoice.
--
-- amount_due is the open amount in the invoice currency. Workday does not return
-- the computed due date on this operation, only due_date_override when someone
-- set one, so the aging in core ages invoices from the invoice date unless an
-- override exists.
--
-- Single tenant. To add another, UNION ALL a second block below pointing at that
-- tenant's connector with a different workday_tenant label.

SELECT
    'tenant_1'                                       AS workday_tenant,
    CAST(id AS STRING)                               AS customer_invoice_id,
    CAST(invoice_number AS STRING)                   AS invoice_number,
    DATE(CAST(invoice_date AS TIMESTAMP))            AS invoice_date,
    DATE(CAST(due_date_override AS TIMESTAMP))       AS due_date_override,
    CAST(company_id AS STRING)                       AS company_id,
    CAST(customer_id AS STRING)                      AS customer_id,
    CAST(customer_descriptor AS STRING)              AS customer_name,
    UPPER(CAST(currency_code AS STRING))             AS currency,
    CAST(control_amount_total AS NUMERIC)            AS total_amount,
    COALESCE(CAST(amount_due AS NUMERIC), 0)         AS amount_due,
    CAST(payment_status AS STRING)                   AS payment_status,
    CAST(document_status AS STRING)                  AS document_status,
    COALESCE(CAST(on_hold AS BOOL), FALSE)           AS is_on_hold
FROM {{ source('workday_financial_management', 'customer_invoice') }}
