-- core_daisycon__invoice_costs_monthly
-- Invoiced affiliate costs per month and invoice line type: what you actually pay
-- Daisycon, split into commission, fees and whatever else the lines say.
--
-- Grain: invoice_month x advertiser_id x currency x line_code. Currency: the invoice's.
-- Depends on: staging.daisycon.financial_invoice_line, .financial_invoice, .advertiser
--
-- Months are the invoice date, not the period the commission was earned in; use
-- period_start_date on core.daisycon.invoices if you need the latter. Line codes are
-- Daisycon's own; the description is the most recent one seen for the code.

SELECT
    DATE_TRUNC(i.invoice_date, MONTH)  AS invoice_month,
    l.advertiser_id,
    ANY_VALUE(a.advertiser_name)       AS advertiser_name,
    i.currency,
    l.line_code,
    ARRAY_AGG(l.line_description IGNORE NULLS ORDER BY i.invoice_date DESC LIMIT 1)[SAFE_OFFSET(0)] AS line_description,
    COUNT(DISTINCT l.invoice_number)   AS invoices,
    SUM(l.quantity)                    AS quantity,
    SUM(l.amount_excl_vat)             AS amount_excl_vat,
    SUM(l.vat)                         AS vat,
    SUM(l.amount_incl_vat)             AS amount_incl_vat
FROM {{ ref('stg_daisycon__financial_invoice_line') }} l
-- Both lookups are one row per key after staging, so these joins cannot fan out.
JOIN {{ ref('stg_daisycon__financial_invoice') }} i
    ON i.advertiser_id = l.advertiser_id AND i.invoice_number = l.invoice_number
LEFT JOIN {{ ref('stg_daisycon__advertiser') }} a
    ON a.advertiser_id = l.advertiser_id
GROUP BY invoice_month, l.advertiser_id, i.currency, l.line_code
