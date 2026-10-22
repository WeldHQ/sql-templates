-- core_recurly__billing_by_month
-- What was invoiced, credited, collected and still owed, by month. The cash-side
-- companion to the MRR models, and the closest match to Recurly's invoice export
-- totalled by month.
--
-- Grain: month x currency. Currency: the invoice currency, major units.
-- Dated on the invoice's created_at. Voided invoices are excluded.
-- Depends on: staging.recurly.invoice
--
-- CHARGE AND CREDIT INVOICES are kept apart. Charge invoices (and pre-2021
-- `legacy` invoices) bill the customer; credit invoices give money back and
-- carry negative amounts, so net_billings is a plain sum:
--   charge_subtotal - charge_discounts = charge_net         (ex tax)
--   charge_net + credit_net = net_billings                  (credit_net is negative)
-- `charge_total` adds tax back on, so it is what customers were asked to pay.
--
-- `failed` invoices (collection gave up) stay in, because they were billed;
-- `failed_total` shows how much of the month's billing that was.

SELECT
    DATE_TRUNC(invoice_date, MONTH)                                     AS month,
    currency,
    COUNTIF(invoice_type IN ('charge', 'legacy'))                       AS charge_invoices,
    SUM(IF(invoice_type IN ('charge', 'legacy'), subtotal, 0))          AS charge_subtotal,
    SUM(IF(invoice_type IN ('charge', 'legacy'), discount, 0))          AS charge_discounts,
    SUM(IF(invoice_type IN ('charge', 'legacy'), subtotal - discount, 0)) AS charge_net,
    SUM(IF(invoice_type IN ('charge', 'legacy'), tax, 0))               AS charge_tax,
    SUM(IF(invoice_type IN ('charge', 'legacy'), total, 0))             AS charge_total,
    COUNTIF(invoice_type = 'credit')                                    AS credit_invoices,
    SUM(IF(invoice_type = 'credit', subtotal - discount, 0))            AS credit_net,
    SUM(IF(invoice_type = 'credit', total, 0))                          AS credit_total,
    SUM(subtotal - discount)                                            AS net_billings,
    SUM(IF(invoice_type IN ('charge', 'legacy'), paid, 0))              AS charge_paid,
    SUM(IF(invoice_type IN ('charge', 'legacy'), balance, 0))           AS charge_balance_due,
    SUM(IF(state = 'failed', total, 0))                                 AS failed_total
FROM {{ ref('stg_recurly__invoice') }}
WHERE state <> 'voided'
GROUP BY 1, 2
