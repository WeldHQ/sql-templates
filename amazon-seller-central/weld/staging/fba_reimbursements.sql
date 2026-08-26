-- staging.amazon_seller.fba_reimbursements
-- Thin wrapper over raw `fba_reimbursements_report`. Casts, renames. No other logic.
--
-- Money Amazon owes you back for inventory it lost, damaged or mis-charged. It is
-- real revenue and it is nobody's KPI, so it usually goes unreconciled - which is
-- exactly why it is worth modelling: a reimbursement for a unit Amazon destroyed
-- last quarter posts today, against an ASIN whose margin you already reported.
--
-- The amount columns are typed as strings in the raw report; cast them.
-- `quantity_reimbursed_cash` and `quantity_reimbursed_inventory` are alternatives,
-- not addends - Amazon either pays you or replaces the unit. Adding both to
-- quantity_reimbursed_total double-counts.

SELECT
    'seller_1'                                                  AS amazon_seller,
    CAST(reimbursement_id AS STRING)                            AS reimbursement_id,
    CAST(original_reimbursement_id AS STRING)                   AS original_reimbursement_id,
    LOWER(CAST(original_reimbursement_type AS STRING))          AS original_reimbursement_type,
    CAST(case_id AS STRING)                                     AS case_id,
    CAST(amazon_order_id AS STRING)                             AS amazon_order_id,

    CAST(approval_date AS DATE)                                 AS approval_date,

    CAST(sku AS STRING)                                         AS sku,
    UPPER(NULLIF(TRIM(CAST(asin AS STRING)), ''))               AS asin,
    CAST(fnsku AS STRING)                                       AS fnsku,
    CAST(product_name AS STRING)                                AS product_name,
    LOWER(CAST(condition AS STRING))                            AS condition,
    LOWER(CAST(reason AS STRING))                               AS reason,
    UPPER(NULLIF(TRIM(CAST(currency_unit AS STRING)), ''))      AS currency,

    CAST(amount_total AS NUMERIC)                               AS reimbursed_amount,
    CAST(amount_per_unit AS NUMERIC)                            AS reimbursed_amount_per_unit,
    CAST(CAST(quantity_reimbursed_total AS NUMERIC) AS INT64)   AS quantity_reimbursed_total,
    CAST(CAST(quantity_reimbursed_cash AS NUMERIC) AS INT64)    AS quantity_reimbursed_cash,
    CAST(CAST(quantity_reimbursed_inventory AS NUMERIC) AS INT64) AS quantity_reimbursed_inventory
FROM {{raw.amazon_seller_central.fba_reimbursements_report}}
