-- staging.amazon_seller.settlement
-- Thin wrapper over raw `settlement_report`. Casts, renames, classifies each line
-- into a ledger category. No aggregation.
--
-- THIS IS THE ONLY TABLE THAT KNOWS WHAT AMAZON ACTUALLY PAID YOU. Everything else
-- in this connector describes what customers ordered. The settlement report is the
-- event log behind the deposit: one row per financial event, positioned in time by
-- `posted_date`, signed so that the whole report sums to the money that hit your
-- bank account.
--
-- RETENTION - READ THIS BEFORE YOUR FIRST FULL REFRESH. Amazon deletes settlement
-- reports after 89 days. Weld cannot re-fetch what Amazon has deleted, so a full
-- re-sync of this stream permanently destroys every settlement older than ~3
-- months. Everything downstream of this model is the only copy of your fee history
-- that exists. Materialise it as a table, never a view, and never reset the stream.
--
-- Amazon also generates these reports on its own schedule, so there will be days
-- with no new rows. That is normal, not a broken sync.

SELECT
    'seller_1'                                                      AS amazon_seller,
    CAST(settlement_id AS STRING)                                   AS settlement_id,
    CAST(order_id AS STRING)                                        AS amazon_order_id,
    CAST(merchant_order_id AS STRING)                               AS merchant_order_id,
    CAST(shipment_id AS STRING)                                     AS shipment_id,
    CAST(adjustment_id AS STRING)                                   AS adjustment_id,
    CAST(sku AS STRING)                                             AS sku,
    UPPER(NULLIF(TRIM(CAST(marketplace_name AS STRING)), ''))       AS marketplace,

    -- posted_date is when the money moved, which is the only date that makes the
    -- ledger tie to a deposit. It is NOT the order date: a January order refunded
    -- in March posts its refund in March.
    CAST(posted_date AS DATE)                                       AS posted_date,
    CAST(posted_date_time AS TIMESTAMP)                             AS posted_at,

    LOWER(NULLIF(TRIM(CAST(transaction_type AS STRING)), ''))       AS transaction_type,
    LOWER(NULLIF(TRIM(CAST(amount_type AS STRING)), ''))            AS amount_type,
    LOWER(NULLIF(TRIM(CAST(amount_description AS STRING)), ''))     AS amount_description,

    -- Already signed by Amazon: revenue positive, fees and refunds negative. Do not
    -- ABS() or flip anything - the report only ties to the deposit total if every
    -- line keeps the sign Amazon gave it.
    CAST(amount AS NUMERIC)                                         AS amount,
    CAST(quantity_purchased AS NUMERIC)                             AS quantity,

    -- One classification, defined once, used by every downstream model. Amazon has
    -- dozens of amount_description values and adds more without notice, so the
    -- buckets key off amount_type - a short, stable enum - and only reach into
    -- amount_description where amount_type is genuinely ambiguous.
    CASE
        WHEN LOWER(CAST(amount_type AS STRING)) = 'itemprice'
             AND LOWER(CAST(amount_description AS STRING)) IN ('principal', 'shipping', 'giftwrap', 'shippingcharge')
            THEN 'revenue'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'itemprice'
             AND LOWER(CAST(amount_description AS STRING)) LIKE '%tax%'
            THEN 'tax_collected'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'itemprice'
             AND LOWER(CAST(amount_description AS STRING)) LIKE '%discount%'
            THEN 'promotion'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'promotion'      THEN 'promotion'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'itemfees'       THEN 'selling_fee'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'orderfee'       THEN 'selling_fee'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'itemwithheldtax' THEN 'tax_withheld'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'orderwithheldtax' THEN 'tax_withheld'
        WHEN LOWER(CAST(amount_type AS STRING)) LIKE 'fba%'        THEN 'fba_fee'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'servicefee'     THEN 'service_fee'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'costofadvertising' THEN 'advertising'
        WHEN LOWER(CAST(amount_type AS STRING)) LIKE '%reimbursement%' THEN 'reimbursement'
        WHEN LOWER(CAST(amount_type AS STRING)) = 'other-transaction' THEN 'other'
        WHEN CAST(amount_type AS STRING) IS NULL                   THEN 'unclassified'
        ELSE 'other'
    END                                                             AS ledger_category,

    -- A refund is identified by transaction_type, not by a negative amount: a fee
    -- is also negative. Getting this backwards is how refunds end up counted as
    -- fees and the fee ratio looks great while margin collapses.
    LOWER(CAST(transaction_type AS STRING)) IN ('refund', 'chargeback', 'guaranteeclaim')
                                                                    AS is_refund
FROM {{raw.amazon_seller_central.settlement_report}}
