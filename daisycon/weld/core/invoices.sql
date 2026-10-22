-- core.daisycon.invoices
-- What Daisycon has invoiced the advertiser, one row per invoice, with the line
-- totals next to the header totals and how long each invoice took to pay.
--
-- Grain: advertiser_id x invoice_number. Currency: per invoice.
-- Depends on: staging.daisycon.financial_invoice, .financial_invoice_line, .advertiser
--
-- lines_amount_excl_vat should equal amount_excl_vat. A gap means a line is
-- missing from the sync, not that Daisycon miscounted.

WITH lines AS (
    SELECT
        advertiser_id,
        invoice_number,
        COUNT(*)             AS line_count,
        SUM(amount_excl_vat) AS lines_amount_excl_vat
    FROM {{staging.daisycon.financial_invoice_line}}
    GROUP BY 1, 2
)

SELECT
    i.advertiser_id,
    a.advertiser_name,
    i.invoice_number,
    i.invoice_date,
    DATE_TRUNC(i.invoice_date, MONTH)             AS invoice_month,
    i.period_start_date,
    i.period_end_date,
    i.due_date,
    i.paid_date,
    i.invoice_status,
    i.paid_date IS NOT NULL                       AS is_paid,
    i.paid_date IS NULL AND i.due_date < CURRENT_DATE() AS is_overdue,
    DATE_DIFF(i.paid_date, i.invoice_date, DAY)   AS days_to_pay,
    i.currency,
    i.amount_excl_vat,
    i.vat,
    i.amount_incl_vat,
    l.line_count,
    l.lines_amount_excl_vat
FROM {{staging.daisycon.financial_invoice}} i
-- lines is grouped to one row per invoice and advertiser is one row per id, so
-- neither join can fan out.
LEFT JOIN lines l
    ON l.advertiser_id = i.advertiser_id AND l.invoice_number = i.invoice_number
LEFT JOIN {{staging.daisycon.advertiser}} a
    ON a.advertiser_id = i.advertiser_id
