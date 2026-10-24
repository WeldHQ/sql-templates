-- core_fortnox__payables_aging
-- Accounts payable aging (leverantörsreskontra): every supplier invoice with an open
-- balance, bucketed by days past due as of today.
--
-- Grain: one row per open supplier invoice. A point-in-time snapshot, like
-- receivables_aging.
--
-- Currency: `balance` is in the invoice currency; `balance_sek` uses the booked rate.
-- Sign: positive is what you owe. Supplier credit notes are negative.

SELECT
    given_number,
    supplier_invoice_number,
    supplier_number,
    supplier_name,
    invoice_date,
    due_date,
    currency,
    total,
    balance,
    total_sek,
    balance_sek,
    is_credit,
    is_payment_pending,
    DATE_DIFF(CURRENT_DATE(), due_date, DAY)          AS days_past_due,
    CASE
        WHEN due_date IS NULL                                 THEN 'no_due_date'
        WHEN DATE_DIFF(CURRENT_DATE(), due_date, DAY) <= 0    THEN 'not_due'
        WHEN DATE_DIFF(CURRENT_DATE(), due_date, DAY) <= 30   THEN '1_30'
        WHEN DATE_DIFF(CURRENT_DATE(), due_date, DAY) <= 60   THEN '31_60'
        WHEN DATE_DIFF(CURRENT_DATE(), due_date, DAY) <= 90   THEN '61_90'
        ELSE 'over_90'
    END                                               AS aging_bucket,
    CURRENT_DATE()                                    AS aged_as_of
FROM {{ ref('stg_fortnox__supplier_invoices') }}
WHERE is_booked
  AND NOT is_cancelled
  AND balance <> 0
