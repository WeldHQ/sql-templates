-- core_harvest__invoice_aging
-- Every sent invoice with what is still owed, how late it is and how long it
-- took to get paid. Harvest's Outstanding Invoices report plus payment speed.
-- Grain: invoice. Drafts are excluded.
--
-- Aging is measured against CURRENT_DATE() (UTC) and the invoice due date.
-- Amounts are in each invoice's own currency: group by currency before summing.
-- days_to_pay uses paid_date, which Harvest sets when the invoice is fully paid.

SELECT
    i.invoice_id,
    i.invoice_number,
    i.client_id,
    i.client_name,
    i.state,
    i.currency,
    i.issue_date,
    i.due_date,
    i.paid_date,
    i.amount,
    i.tax_amount,
    i.due_amount,
    i.amount - i.due_amount                                      AS paid_amount,
    IF(i.state = 'open', GREATEST(DATE_DIFF(CURRENT_DATE(), i.due_date, DAY), 0), NULL) AS days_overdue,
    CASE
        WHEN i.state != 'open' OR i.due_amount <= 0          THEN NULL
        WHEN CURRENT_DATE() <= i.due_date                    THEN 'not_due'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 30 THEN '1_30'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 60 THEN '31_60'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 90 THEN '61_90'
        ELSE 'over_90'
    END                                                          AS aging_bucket,
    IF(i.state = 'paid', DATE_DIFF(i.paid_date, i.issue_date, DAY), NULL) AS days_to_pay,
    IF(i.state = 'paid', i.paid_date > i.due_date, NULL)         AS paid_late
FROM {{ ref('stg_harvest__invoice') }} i
WHERE i.state != 'draft'
