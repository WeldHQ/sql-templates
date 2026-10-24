-- core_fortnox__receivables_aging
-- Accounts receivable aging (kundreskontra, förfallna fakturor): every customer invoice
-- with an open balance, bucketed by days past due as of today.
--
-- Grain: one row per open customer invoice. A point-in-time snapshot: the buckets move
-- every day and the model keeps no history. Materialise a dated copy on a schedule if
-- you want aging over time.
--
-- Currency: `balance` is in the invoice currency (`currency`); `balance_sek` converts it
-- at the rate booked on the invoice, which is what the ledger carries. Sum `balance_sek`
-- across currencies, never `balance`.
-- Sign: positive is owed to you. Credit invoices with an unused balance are negative and
-- are kept, so the total nets them off as Fortnox does.
--
-- Open means booked, not cancelled and a non-zero balance. Unbooked invoices are drafts
-- and are not in the ledger yet.

SELECT
    invoice_number,
    customer_number,
    customer_name,
    invoice_date,
    due_date,
    currency,
    total,
    balance,
    total_sek,
    balance_sek,
    is_credit,
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
FROM {{ ref('stg_fortnox__invoices') }}
WHERE is_booked
  AND NOT is_cancelled
  AND balance <> 0
