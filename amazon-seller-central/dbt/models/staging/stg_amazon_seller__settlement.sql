-- stg_amazon_seller__settlement
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

-- Normalise the three enum columns ONCE, here, and classify off the normalised
-- values below. Amazon pads these fields inconsistently and sometimes sends an empty
-- string rather than NULL, so a classifier that re-derives `LOWER(CAST(x AS STRING))`
-- inline would compare ' itemfees ' against 'itemfees' and silently bucket a real fee
-- as 'other' - while the output column, trimmed, looked correct. Empty strings become
-- NULL for the same reason, so they land in 'unclassified' where they are visible
-- rather than in 'other' where they are not.

{{ config(materialized='table') }}
WITH normalised AS (
    SELECT
        settlement_id,
        order_id,
        merchant_order_id,
        shipment_id,
        adjustment_id,
        sku,
        marketplace_name,
        posted_date,
        posted_date_time,
        amount,
        quantity_purchased,

        LOWER(NULLIF(TRIM(CAST(transaction_type AS STRING)), ''))   AS transaction_type,
        LOWER(NULLIF(TRIM(CAST(amount_type AS STRING)), ''))        AS amount_type,
        LOWER(NULLIF(TRIM(CAST(amount_description AS STRING)), '')) AS amount_description,

        -- This report names the marketplace by domain; everything downstream keys on
        -- marketplace_id. Resolved below so the fee ledger actually joins to the
        -- sales models: core_amazon_seller__asin_profitability joins on
        -- (date, seller, marketplace, sku), so an unresolved key silently yields
        -- sales rows with no fees and fee rows with no sales - and a margin that
        -- looks wonderful.
        LOWER(NULLIF(TRIM(CAST(marketplace_name AS STRING)), ''))   AS marketplace_domain
    FROM {{ source('amazon_seller_central', 'settlement_report') }}
)

SELECT
    'seller_1'                                                      AS amazon_seller,
    CAST(settlement_id AS STRING)                                   AS settlement_id,
    CAST(order_id AS STRING)                                        AS amazon_order_id,
    CAST(merchant_order_id AS STRING)                               AS merchant_order_id,
    CAST(shipment_id AS STRING)                                     AS shipment_id,
    CAST(adjustment_id AS STRING)                                   AS adjustment_id,
    CAST(sku AS STRING)                                             AS sku,
    COALESCE(m.marketplace_id, UPPER(n.marketplace_domain))         AS marketplace,
    n.marketplace_domain,

    -- posted_date is when the money moved, which is the only date that makes the
    -- ledger tie to a deposit. It is NOT the order date: a January order refunded
    -- in March posts its refund in March.
    CAST(posted_date AS DATE)                                       AS posted_date,
    CAST(posted_date_time AS TIMESTAMP)                             AS posted_at,

    transaction_type,
    amount_type,
    amount_description,

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
        WHEN amount_type = 'itemprice'
             AND amount_description IN ('principal', 'shipping', 'giftwrap', 'shippingcharge')
            THEN 'revenue'
        WHEN amount_type = 'itemprice' AND amount_description LIKE '%tax%'
            THEN 'tax_collected'
        WHEN amount_type = 'itemprice' AND amount_description LIKE '%discount%'
            THEN 'promotion'
        WHEN amount_type = 'promotion'         THEN 'promotion'
        WHEN amount_type = 'itemfees'          THEN 'selling_fee'
        WHEN amount_type = 'orderfee'          THEN 'selling_fee'
        WHEN amount_type = 'itemwithheldtax'   THEN 'tax_withheld'
        WHEN amount_type = 'orderwithheldtax'  THEN 'tax_withheld'
        WHEN amount_type LIKE 'fba%'           THEN 'fba_fee'
        WHEN amount_type = 'servicefee'        THEN 'service_fee'
        WHEN amount_type = 'costofadvertising' THEN 'advertising'
        WHEN amount_type LIKE '%reimbursement%' THEN 'reimbursement'
        WHEN amount_type = 'other-transaction' THEN 'other'
        WHEN amount_type IS NULL               THEN 'unclassified'
        ELSE 'other'
    END                                                             AS ledger_category,

    -- A refund is identified by transaction_type, not by a negative amount: a fee
    -- is also negative. Getting this backwards is how refunds end up counted as
    -- fees and the fee ratio looks great while margin collapses.
    transaction_type IN ('refund', 'chargeback', 'guaranteeclaim')   AS is_refund
FROM normalised n
LEFT JOIN {{ ref('stg_amazon_seller__marketplace') }} m
       ON m.marketplace_domain = n.marketplace_domain
