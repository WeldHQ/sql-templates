-- core_quickbooks__ar_ap_aging
-- Open invoices and open bills, bucketed by days past due as of today. The
-- document-level detail behind QuickBooks' A/R Aging and A/P Aging reports.
--
-- Grain: company x side x document. side is 'receivable' (invoices) or 'payable'
-- (bills). Only documents with an open balance are kept.
--
-- This is the current state, not history: QuickBooks only exposes today's open
-- balance, so the aging cannot be rebuilt for a past date from these tables.
--
-- Currency: open_balance is in the document's own currency (currency column);
-- open_balance_home is in the company's home currency and is the one to sum.
--
-- Buckets follow the report's defaults: Current (not yet due), 1-30, 31-60,
-- 61-90, 91 and over, by days past the due date. A document without a due date
-- is aged from its transaction date.
--
-- Differences from QuickBooks' own aging reports: unapplied customer payments,
-- open credit memos and vendor credits are not included, so the totals here are
-- gross of credits and can be higher than the report's.

WITH open_documents AS (
    SELECT
        quickbooks_company,
        'receivable'  AS side,
        invoice_id    AS document_id,
        doc_number,
        customer_id   AS counterparty_id,
        customer_name AS counterparty_name,
        txn_date,
        due_date,
        currency,
        exchange_rate,
        total_amount,
        open_balance,
        open_balance_home
    FROM {{ ref('stg_quickbooks__invoice') }}
    WHERE open_balance != 0

    UNION ALL

    SELECT
        quickbooks_company,
        'payable'     AS side,
        bill_id       AS document_id,
        doc_number,
        vendor_id     AS counterparty_id,
        vendor_name   AS counterparty_name,
        txn_date,
        due_date,
        currency,
        exchange_rate,
        total_amount,
        open_balance,
        open_balance_home
    FROM {{ ref('stg_quickbooks__bill') }}
    WHERE open_balance != 0
),

aged AS (
    SELECT
        *,
        CURRENT_DATE()                                                AS as_of_date,
        DATE_DIFF(CURRENT_DATE(), COALESCE(due_date, txn_date), DAY)  AS days_past_due
    FROM open_documents
)

SELECT
    *,
    CASE
        WHEN days_past_due IS NULL THEN 'Unknown'
        WHEN days_past_due <= 0    THEN 'Current'
        WHEN days_past_due <= 30   THEN '1-30'
        WHEN days_past_due <= 60   THEN '31-60'
        WHEN days_past_due <= 90   THEN '61-90'
        ELSE '91 and over'
    END AS aging_bucket,
    CASE
        WHEN days_past_due IS NULL THEN 6
        WHEN days_past_due <= 0    THEN 1
        WHEN days_past_due <= 30   THEN 2
        WHEN days_past_due <= 60   THEN 3
        WHEN days_past_due <= 90   THEN 4
        ELSE 5
    END AS aging_bucket_order
FROM aged
