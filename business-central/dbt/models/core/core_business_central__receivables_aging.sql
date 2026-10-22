-- core_business_central__receivables_aging
-- Accounts receivable aging at invoice level: every open posted sales invoice with a
-- remaining amount, bucketed by days past due as of today.
--
-- Grain: one row per open sales invoice (company x invoice). A point-in-time snapshot:
-- buckets move every day and no history is kept.
-- Currency: the invoice's own currency (`currency_code`, filled with the company's local
-- currency where Business Central leaves it blank). Amounts are not converted, so sum
-- per currency. Business Central's own Aged Accounts Receivable (the
-- `aged_accounts_receivable` stream) reports per customer in LCY and is the figure to
-- reconcile totals against.
-- Sign: positive is owed to you.
--
-- Unapplied credit memos and unapplied payments are not in the sales invoice stream, so
-- they are not netted here; Business Central's aged report nets them. Expect this model
-- to be higher by exactly those amounts.

SELECT
    i.company_id,
    c.company_name,
    i.invoice_id,
    i.invoice_number,
    i.customer_id,
    i.customer_number,
    i.customer_name,
    i.invoice_date,
    i.due_date,
    COALESCE(i.currency_code, c.local_currency_code)  AS currency_code,
    i.currency_code IS NULL                           AS is_local_currency,
    i.total_amount_including_tax,
    i.remaining_amount,
    DATE_DIFF(CURRENT_DATE(), i.due_date, DAY)        AS days_past_due,
    CASE
        WHEN i.due_date IS NULL                               THEN 'no_due_date'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 0  THEN 'not_due'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 30 THEN '1_30'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 60 THEN '31_60'
        WHEN DATE_DIFF(CURRENT_DATE(), i.due_date, DAY) <= 90 THEN '61_90'
        ELSE 'over_90'
    END                                               AS aging_bucket,
    CURRENT_DATE()                                    AS aged_as_of
FROM {{ ref('stg_business_central__sales_invoices') }} i
LEFT JOIN {{ ref('stg_business_central__company_information') }} c
       ON c.company_id = i.company_id
-- Open = posted and not fully paid. Drafts are not posted and have no ledger effect.
WHERE LOWER(i.status) = 'open'
  AND i.remaining_amount <> 0
