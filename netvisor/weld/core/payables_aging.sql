-- core.netvisor.payables_aging
-- Accounts payable aging (ostoreskontra, avoimet ostolaskut): every purchase invoice
-- with an unpaid amount, bucketed by days past due as of today.
--
-- Grain: one row per open purchase invoice. A point-in-time snapshot: buckets move every
-- day and no history is kept. Materialise a dated copy on a schedule for aging over time.
--
-- Currency: the company's accounting currency (EUR); the purchase invoice payload has no
-- currency code. Sign: positive is what you owe; credit notes are negative and kept, so
-- totals net them off.
--
-- Open means `amount - paid_amount` is not zero. Invoices still awaiting approval are
-- included, because they are owed regardless; filter on `approval_status` if you want
-- only approved ones.

SELECT
    purchase_invoice_key,
    purchase_invoice_number,
    vendor_key,
    vendor_code,
    vendor_name,
    invoice_date,
    due_date,
    amount,
    paid_amount,
    open_amount,
    invoice_status,
    approval_status,
    is_accounted,
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
FROM {{staging.netvisor.purchase_invoices}}
WHERE ABS(open_amount) > 0.005
