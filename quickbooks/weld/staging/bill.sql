-- staging.quickbooks.bill
-- Supplier bills, header level, used for the payables side of the aging.
--
-- Grain: one row per bill.
--
-- txn_date and due_date arrive as 'YYYY-MM-DD' strings on this stream and are
-- parsed here. total_amt and balance are in the bill's own currency; home_balance
-- is only returned for multicurrency companies, so balance is used otherwise.
-- Deleted bills are not removed from the raw table by an incremental sync.
--
-- Single company. To add another, UNION ALL a second block below pointing at that
-- company's connector with a different quickbooks_company label.

SELECT
    'company_1'                                   AS quickbooks_company,
    CAST(id AS STRING)                            AS bill_id,
    CAST(doc_number AS STRING)                    AS doc_number,
    CAST(vendor_ref_value AS STRING)              AS vendor_id,
    CAST(vendor_ref_name AS STRING)               AS vendor_name,
    SAFE_CAST(SUBSTR(CAST(txn_date AS STRING), 1, 10) AS DATE) AS txn_date,
    SAFE_CAST(SUBSTR(CAST(due_date AS STRING), 1, 10) AS DATE) AS due_date,
    UPPER(CAST(currency_ref_value AS STRING))     AS currency,
    CAST(exchange_rate AS NUMERIC)                AS exchange_rate,
    COALESCE(CAST(total_amt AS NUMERIC), 0)       AS total_amount,
    COALESCE(CAST(balance AS NUMERIC), 0)         AS open_balance,
    COALESCE(
        CAST(home_balance AS NUMERIC),
        CAST(balance AS NUMERIC) * COALESCE(CAST(exchange_rate AS NUMERIC), 1)
    )                                             AS open_balance_home
FROM {{raw.quickbooks.bill}}
