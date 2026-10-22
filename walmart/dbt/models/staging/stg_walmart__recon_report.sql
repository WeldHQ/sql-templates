-- stg_walmart__recon_report
-- Thin wrapper over raw `recon_report`: Walmart's settlement reconciliation
-- file, one row per line, one file per settlement (payout) date.
--
-- THIS IS THE ONLY TABLE THAT KNOWS WHAT WALMART PAID YOU. Each file has one
-- PaymentSummary line carrying total_payable, the amount deposited, and then one
-- line per money movement: sales, refunds, commission, fees, adjustments.
-- Amounts keep Walmart's sign. Nothing is flipped, which is what lets the lines
-- sum back to the deposit.
--
-- Dates in the file are calendar dates without a time, so they are read as dates
-- and never shifted by a timezone.
--
-- amount_type and transaction_type are normalised once here (trimmed, lower
-- case, empty string to NULL) and classified once into ledger_category, so core
-- never re-derives them inconsistently. Walmart adds amount types without
-- notice: anything not recognised lands in 'other', and a missing amount type in
-- 'unclassified', both visible in the ledger.

WITH normalised AS (
    SELECT
        *,
        LOWER(NULLIF(TRIM(CAST(transaction_type AS STRING)), '')) AS transaction_type_norm,
        LOWER(NULLIF(TRIM(CAST(amount_type AS STRING)), ''))      AS amount_type_norm
    FROM {{ source('walmart', 'recon_report') }}
)

SELECT
    'seller_1'                                         AS walmart_seller,
    DATE(CAST(report_date AS TIMESTAMP))               AS settlement_date,
    CAST(row_number AS INT64)                          AS row_number,
    DATE(CAST(period_start_date AS TIMESTAMP))         AS period_start_date,
    DATE(CAST(period_end_date AS TIMESTAMP))           AS period_end_date,
    UPPER(CAST(currency AS STRING))                    AS currency,
    CAST(total_payable AS NUMERIC)                     AS total_payable,
    CAST(transaction_key AS STRING)                    AS transaction_key,
    DATE(CAST(transaction_posted_timestamp AS TIMESTAMP)) AS posted_date,
    transaction_type_norm                              AS transaction_type,
    CAST(transaction_description AS STRING)            AS transaction_description,
    CAST(customer_order AS STRING)                     AS customer_order_id,
    CAST(purchase_order AS STRING)                     AS purchase_order_id,
    CAST(purchase_order_line AS STRING)                AS purchase_order_line,
    CAST(partner_item_id AS STRING)                    AS sku,
    CAST(partner_item_name AS STRING)                  AS product_name,
    CAST(fulfillment_type AS STRING)                   AS fulfillment_type,
    amount_type_norm                                   AS amount_type,
    COALESCE(CAST(amount AS NUMERIC), 0)               AS amount,
    CAST(ship_qty AS NUMERIC)                          AS ship_qty,

    transaction_type_norm = 'paymentsummary'           AS is_summary_line,
    transaction_type_norm = 'refund'                   AS is_refund,

    CASE
        WHEN transaction_type_norm = 'paymentsummary' THEN 'summary'
        WHEN amount_type_norm IS NULL                 THEN 'unclassified'
        WHEN amount_type_norm LIKE '%commission%'     THEN 'commission'
        WHEN amount_type_norm LIKE '%withheld%'       THEN 'tax_withheld'
        WHEN amount_type_norm LIKE '%tax%'            THEN 'tax_collected'
        WHEN amount_type_norm = 'product price'       THEN 'product'
        WHEN amount_type_norm LIKE '%shipping%'       THEN 'shipping'
        WHEN amount_type_norm LIKE '%fee%'
          OR amount_type_norm LIKE '%reimbursement%'  THEN 'fee_or_reimbursement'
        ELSE 'other'
    END                                                AS ledger_category
FROM normalised
