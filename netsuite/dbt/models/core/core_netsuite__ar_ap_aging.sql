-- core_netsuite__ar_ap_aging
-- Open customer invoices and vendor bills, bucketed by days past due as of today.
-- The document-level detail behind NetSuite's A/R Aging and A/P Aging reports.
--
-- Grain: transaction, one row per open invoice (CustInvc) or bill (VendBill).
-- side is 'receivable' or 'payable'.
--
-- This is the current state: NetSuite's open amount as of the last sync. It
-- cannot be rebuilt for a past date from these tables.
--
-- Currency: open_amount is in the transaction currency (currency_id);
-- open_amount_base is converted to the subsidiary's base currency at the
-- transaction's own exchange rate, which is how NetSuite carries it on the
-- receivable or payable account. Sum open_amount_base per subsidiary.
--
-- Buckets: Current (not yet due), 1-30, 31-60, 61-90, 91 and over, by days past
-- the due date. A document without a due date is aged from its transaction date.
--
-- Credit memos, vendor credits and unapplied payments are not netted in, so the
-- totals are gross of credits and can be higher than NetSuite's aging report.

WITH main_line AS (
    -- The header line carries the subsidiary. One per transaction in NetSuite;
    -- grouped anyway so a stray second main line cannot duplicate a document.
    SELECT
        netsuite_account,
        transaction_id,
        ANY_VALUE(subsidiary_id) AS subsidiary_id
    FROM {{ ref('stg_netsuite__transaction_line') }}
    WHERE is_main_line
    GROUP BY 1, 2
),

open_documents AS (
    SELECT
        t.netsuite_account,
        ml.subsidiary_id,
        IF(t.transaction_type = 'CustInvc', 'receivable', 'payable') AS side,
        t.transaction_id,
        t.transaction_type,
        t.document_number,
        t.entity_id                                       AS counterparty_id,
        e.entity_name                                     AS counterparty_name,
        t.transaction_date,
        t.due_date,
        t.status,
        t.currency_id,
        t.exchange_rate,
        t.foreign_total                                   AS total_amount,
        t.foreign_amount_unpaid                           AS open_amount,
        t.foreign_amount_unpaid * COALESCE(t.exchange_rate, 1) AS open_amount_base
    FROM {{ ref('stg_netsuite__transaction') }} t
    LEFT JOIN {{ ref('stg_netsuite__deleted_record') }} d
        ON  d.netsuite_account = t.netsuite_account
        AND d.record_type      = t.record_type
        AND d.record_id        = t.transaction_id
    LEFT JOIN main_line ml
        ON  ml.netsuite_account = t.netsuite_account
        AND ml.transaction_id   = t.transaction_id
    LEFT JOIN {{ ref('stg_netsuite__entity') }} e
        ON  e.netsuite_account = t.netsuite_account
        AND e.entity_id        = t.entity_id
    WHERE t.transaction_type IN ('CustInvc', 'VendBill')
      AND d.record_id IS NULL
      AND NOT t.is_voided
      AND COALESCE(t.foreign_amount_unpaid, 0) != 0
),

aged AS (
    SELECT
        *,
        CURRENT_DATE()                                                       AS as_of_date,
        DATE_DIFF(CURRENT_DATE(), COALESCE(due_date, transaction_date), DAY) AS days_past_due
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
