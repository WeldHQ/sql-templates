-- core_workday_financial_management__ar_aging
-- Open customer invoices, bucketed by age as of today.
--
-- Grain: one row per customer invoice with an amount due.
--
-- This is the current state: Workday's amount due as of the last sync. It cannot
-- be rebuilt for a past date from these tables.
--
-- Age basis: Workday does not return the computed due date on this operation. An
-- invoice with a due date override is aged from that date (days past due); every
-- other invoice is aged from its invoice date (days outstanding). aging_basis says
-- which, and the two should not be read as the same measure. To age by due date
-- throughout, join your payment terms and add the term days to invoice_date.
--
-- Currency: amount_due is in the invoice currency (currency). Sum per currency.
--
-- Cancelled invoices are left out. There is no payables aging: the supplier
-- invoice operation does not return an open amount.

WITH open_invoices AS (
    SELECT
        i.*,
        c.company_name,
        c.company_currency
    FROM {{ ref('stg_workday_financial_management__customer_invoice') }} i
    LEFT JOIN {{ ref('stg_workday_financial_management__company') }} c
        ON  c.workday_tenant = i.workday_tenant
        AND c.company_id     = i.company_id
    WHERE i.amount_due != 0
      AND LOWER(COALESCE(i.document_status, '')) NOT LIKE '%cancel%'
),

aged AS (
    SELECT
        *,
        CURRENT_DATE()                                                       AS as_of_date,
        IF(due_date_override IS NOT NULL, 'due date', 'invoice date')        AS aging_basis,
        DATE_DIFF(CURRENT_DATE(), COALESCE(due_date_override, invoice_date), DAY) AS days_aged
    FROM open_invoices
)

SELECT
    *,
    CASE
        WHEN days_aged IS NULL THEN 'Unknown'
        WHEN days_aged <= 0    THEN 'Current'
        WHEN days_aged <= 30   THEN '1-30'
        WHEN days_aged <= 60   THEN '31-60'
        WHEN days_aged <= 90   THEN '61-90'
        ELSE '91 and over'
    END AS aging_bucket,
    CASE
        WHEN days_aged IS NULL THEN 6
        WHEN days_aged <= 0    THEN 1
        WHEN days_aged <= 30   THEN 2
        WHEN days_aged <= 60   THEN 3
        WHEN days_aged <= 90   THEN 4
        ELSE 5
    END AS aging_bucket_order
FROM aged
