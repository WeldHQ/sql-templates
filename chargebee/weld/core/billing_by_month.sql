-- core.chargebee.billing_by_month
-- What was invoiced, credited, paid and written off, by month. The cash-side
-- companion to the MRR models, and the closest match to Chargebee's invoice and
-- credit note exports totalled by month.
--
-- Grain: month x currency. Currency: the document currency, major units.
-- Invoices are dated on the invoice date, credit notes on the credit note date.
-- Voided invoices and voided credit notes are excluded.
-- Depends on: staging.chargebee.invoice, invoice_line_item, credit_note
--
-- THE EQUATION, all ex tax:
--   gross_invoiced - invoice_discounts = invoiced_sub_total
--   invoiced_sub_total - credit_notes_sub_total = net_billings
-- `invoice_total` adds tax back on, so it is what customers were asked to pay.
--
-- Each source is aggregated to month x currency on its own before the join, so
-- no invoice is counted once per line.

WITH invoices AS (
    SELECT
        DATE_TRUNC(invoice_date, MONTH)                 AS month,
        currency,
        COUNT(*)                                        AS invoices,
        SUM(sub_total)                                  AS invoiced_sub_total,
        SUM(IF(is_recurring, sub_total, 0))             AS recurring_invoiced_sub_total,
        SUM(tax)                                        AS invoice_tax,
        SUM(total)                                      AS invoice_total,
        SUM(amount_paid)                                AS amount_paid,
        SUM(credits_applied)                            AS credits_applied,
        SUM(write_off_amount)                           AS written_off,
        SUM(amount_due)                                 AS amount_due
    FROM {{staging.chargebee.invoice}}
    WHERE status <> 'voided'
    GROUP BY 1, 2
),

invoice_lines AS (
    SELECT
        DATE_TRUNC(i.invoice_date, MONTH)               AS month,
        i.currency,
        SUM(l.amount)                                   AS gross_invoiced,
        SUM(l.discount_amount)                          AS invoice_discounts
    FROM {{staging.chargebee.invoice_line_item}} l
    JOIN {{staging.chargebee.invoice}} i
      ON i.invoice_id = l.invoice_id
    WHERE i.status <> 'voided'
    GROUP BY 1, 2
),

credit_notes AS (
    SELECT
        DATE_TRUNC(credit_note_date, MONTH)             AS month,
        currency,
        COUNT(*)                                        AS credit_notes,
        SUM(sub_total)                                  AS credit_notes_sub_total,
        SUM(amount_refunded)                            AS amount_refunded
    FROM {{staging.chargebee.credit_note}}
    WHERE status <> 'voided'
    GROUP BY 1, 2
),

keys AS (
    SELECT month, currency FROM invoices
    UNION DISTINCT
    SELECT month, currency FROM credit_notes
)

SELECT
    k.month,
    k.currency,
    COALESCE(i.invoices, 0)                             AS invoices,
    COALESCE(l.gross_invoiced, 0)                       AS gross_invoiced,
    COALESCE(l.invoice_discounts, 0)                    AS invoice_discounts,
    COALESCE(i.invoiced_sub_total, 0)                   AS invoiced_sub_total,
    COALESCE(i.recurring_invoiced_sub_total, 0)         AS recurring_invoiced_sub_total,
    COALESCE(i.invoice_tax, 0)                          AS invoice_tax,
    COALESCE(i.invoice_total, 0)                        AS invoice_total,
    COALESCE(c.credit_notes, 0)                         AS credit_notes,
    COALESCE(c.credit_notes_sub_total, 0)               AS credit_notes_sub_total,
    COALESCE(i.invoiced_sub_total, 0)
      - COALESCE(c.credit_notes_sub_total, 0)           AS net_billings,
    COALESCE(i.amount_paid, 0)                          AS amount_paid,
    COALESCE(i.credits_applied, 0)                      AS credits_applied,
    COALESCE(i.written_off, 0)                          AS written_off,
    COALESCE(i.amount_due, 0)                           AS amount_due,
    COALESCE(c.amount_refunded, 0)                      AS amount_refunded
FROM keys k
LEFT JOIN invoices i      ON i.month = k.month AND i.currency = k.currency
LEFT JOIN invoice_lines l ON l.month = k.month AND l.currency = k.currency
LEFT JOIN credit_notes c  ON c.month = k.month AND c.currency = k.currency
