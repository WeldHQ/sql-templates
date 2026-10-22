-- stg_walmart__order_line_refund_charge
-- Thin wrapper over raw `order_line_refund_charge`: one row per refunded charge
-- on an order line.
--
-- Refunds are stored NEGATIVE here whatever sign Walmart sent, so downstream they
-- reduce sales by plain addition. The orders API carries no refund date; the
-- refund is known only as belonging to its order line.

SELECT
    'seller_1'                                            AS walmart_seller,
    CAST(purchase_order_id AS STRING)                     AS purchase_order_id,
    CAST(line_number AS STRING)                           AS line_number,
    CAST(index AS INT64)                                  AS refund_index,
    CAST(refund_reason AS STRING)                         AS refund_reason,
    UPPER(CAST(charge_charge_type AS STRING))             AS charge_type,
    UPPER(CAST(charge_charge_amount_currency AS STRING))  AS currency,
    -ABS(COALESCE(CAST(charge_charge_amount_amount AS NUMERIC), 0)) AS refund_amount,
    -ABS(COALESCE(
        CAST(charge_tax_and_other_fees_tax_and_other_fees_amount_amount AS NUMERIC),
        CAST(charge_tax_tax_amount_amount AS NUMERIC),
        0
    ))                                                    AS refund_tax_amount
FROM {{ source('walmart', 'order_line_refund_charge') }}
WHERE purchase_order_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_order_id, line_number, index ORDER BY _weld_synced DESC) = 1
