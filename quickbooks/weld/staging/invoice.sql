-- staging.quickbooks.invoice
-- Customer invoices, header level, used for the receivables side of the aging.
--
-- Grain: one row per invoice.
--
-- total_amt and balance are in the invoice's own currency. home_balance is the
-- open balance in the company's home currency, and QuickBooks only returns it when
-- multicurrency is switched on; without multicurrency every invoice is already in
-- the home currency, so balance is used. Deleted invoices are not removed from the
-- raw table by an incremental sync, so a deleted invoice keeps its last balance.
--
-- Single company. To add another, UNION ALL a second block below pointing at that
-- company's connector with a different quickbooks_company label.

SELECT
    'company_1'                                   AS quickbooks_company,
    CAST(id AS STRING)                            AS invoice_id,
    CAST(doc_number AS STRING)                    AS doc_number,
    CAST(customer_ref_value AS STRING)            AS customer_id,
    CAST(customer_ref_name AS STRING)             AS customer_name,
    DATE(CAST(txn_date AS TIMESTAMP))             AS txn_date,
    DATE(CAST(due_date AS TIMESTAMP))             AS due_date,
    UPPER(CAST(currency_ref_value AS STRING))     AS currency,
    CAST(exchange_rate AS NUMERIC)                AS exchange_rate,
    COALESCE(CAST(total_amt AS NUMERIC), 0)       AS total_amount,
    COALESCE(CAST(balance AS NUMERIC), 0)         AS open_balance,
    COALESCE(
        CAST(home_balance AS NUMERIC),
        CAST(balance AS NUMERIC) * COALESCE(CAST(exchange_rate AS NUMERIC), 1)
    )                                             AS open_balance_home
FROM {{raw.quickbooks.invoice}}
