-- stg_claimlane__b2b_ticket_product
-- Thin wrapper over raw `b2b_ticket_product`. One row per product line on a
-- business claim, with the supplier's decision on that line.
--
-- status is Claimlane's per-line decision: notHandled, declined, acceptedCredit,
-- acceptedCreditAndRecycle, acceptedReturn, acceptedReturnToSupplier,
-- acceptedNoClaim or other. It is kept verbatim here and grouped in core.
--
-- The connector syncs no price on B2B lines, so B2B claims can be counted but
-- not valued.

SELECT
    'account_1'                                    AS claimlane_account,
    CAST(ticket_id AS STRING)                      AS ticket_id,
    CAST(`index` AS INT64)                         AS product_index,
    CAST(quantity AS NUMERIC)                      AS quantity,
    NULLIF(TRIM(CAST(status AS STRING)), '')       AS status,
    NULLIF(TRIM(CAST(ean AS STRING)), '')          AS ean,
    NULLIF(TRIM(CAST(serial_number AS STRING)), '') AS serial_number,
    NULLIF(TRIM(CAST(invoice_number AS STRING)), '') AS invoice_number
FROM {{ source('claimlane', 'b2b_ticket_product') }}
