-- staging.walmart.order_line_charge
-- Thin wrapper over raw `order_line_charge`: one row per charge on an order
-- line, typically one PRODUCT charge and sometimes a SHIPPING charge.
--
-- Tax on a charge arrives in one of two shapes: Walmart's documentation puts it
-- under tax.taxAmount, while live responses nest it under
-- taxAndOtherFees.taxAndOtherFeesAmount. Both are read and the populated one is
-- used, never both.

SELECT
    'seller_1'                                    AS walmart_seller,
    CAST(purchase_order_id AS STRING)             AS purchase_order_id,
    CAST(line_number AS STRING)                   AS line_number,
    CAST(index AS INT64)                          AS charge_index,
    UPPER(CAST(charge_type AS STRING))            AS charge_type,
    CAST(charge_name AS STRING)                   AS charge_name,
    UPPER(CAST(charge_amount_currency AS STRING)) AS currency,
    COALESCE(CAST(charge_amount_amount AS NUMERIC), 0) AS charge_amount,
    COALESCE(
        CAST(tax_and_other_fees_tax_and_other_fees_amount_amount AS NUMERIC),
        CAST(tax_tax_amount_amount AS NUMERIC),
        0
    )                                             AS tax_amount
FROM {{raw.walmart.order_line_charge}}
WHERE purchase_order_id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY purchase_order_id, line_number, index ORDER BY _weld_synced DESC) = 1
