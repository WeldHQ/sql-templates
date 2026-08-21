-- stg_amazon_seller__returns
-- Thin wrapper over raw `returns_by_return_date_report` - seller-fulfilled (MFN)
-- returns. Casts, renames, signs the money negative. No other logic.
--
-- THE DATE THAT MATTERS IS return_request_date. Amazon's Business Reports attribute
-- a refund to the day it was requested, not to the day the original order was
-- placed. Attribute it back to order_date and you restate history every time an old
-- order comes back: last month's revenue changes after you have reported it.
-- order_date is kept as a separate column so you can measure return lag, which is
-- what it is actually good for.
--
-- FBA returns are a DIFFERENT report with a different grain - see
-- stg_amazon_seller__fba_returns. Union them and you double-count any account
-- running both channels.

SELECT
    'seller_1'                                                  AS amazon_seller,
    UPPER(NULLIF(TRIM(CAST(marketplace_id AS STRING)), ''))     AS marketplace,

    CAST(order_id AS STRING)                                    AS amazon_order_id,
    CAST(merchant_sku AS STRING)                                AS sku,
    UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
    CAST(item_name AS STRING)                                   AS product_name,

    CAST(return_request_date AS DATE)                           AS return_date,
    CAST(order_date AS DATE)                                    AS order_date,
    CAST(return_delivery_date AS DATE)                          AS return_delivery_date,

    LOWER(CAST(return_request_status AS STRING))                AS return_status,
    LOWER(CAST(return_type AS STRING))                          AS return_type,
    LOWER(CAST(return_reason AS STRING))                        AS return_reason,
    LOWER(CAST(resolution AS STRING))                           AS resolution,
    COALESCE(CAST(in_policy AS BOOL), FALSE)                    AS is_in_policy,
    COALESCE(CAST(a_to_z_claim AS BOOL), FALSE)                 AS is_a_to_z_claim,
    UPPER(NULLIF(TRIM(CAST(currency_code AS STRING)), ''))      AS currency,

    -- Negative, matching the discount convention in stg_amazon_seller__orders,
    -- so net = gross + discounts + returns stays plain addition everywhere.
    -1 * ABS(CAST(return_quantity AS INT64))                    AS return_quantity,
    -1 * ABS(CAST(refunded_amount AS NUMERIC))                  AS refunded_amount,

    -- Return shipping label costs are a real cost of the return and are usually
    -- forgotten. Negative for the same reason.
    -1 * ABS(COALESCE(CAST(label_cost AS NUMERIC), 0))          AS return_label_cost,
    LOWER(CAST(label_to_be_paid_by AS STRING))                  AS label_paid_by,

    -- SAFE-T reimburses you when a buyer damages an item they returned. It offsets
    -- the refund, so it belongs alongside it rather than in a separate report.
    ABS(COALESCE(CAST(safe_t_claim_reimbursement_amount AS NUMERIC), 0)) AS safe_t_reimbursement,
    LOWER(CAST(safe_t_claim_state AS STRING))                   AS safe_t_claim_state,

    'MFN'                                                       AS return_channel
FROM {{ source('amazon_seller_central', 'returns_by_return_date_report') }}
