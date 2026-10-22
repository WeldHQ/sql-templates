-- stg_traede__invoice_line
-- Thin wrapper over raw `invoice_line`. One row per invoice line.
--
-- UNITS: as on order lines, `price_before_discount`, `discount_amount`,
-- `net_price` and `vat_amount` are PER UNIT. `total_price` is the line total ex
-- VAT (quantity x net_price). The per-unit gross and discount are multiplied out
-- here so core can sum line amounts without remembering which fields are unit
-- prices.

SELECT
    'account_1'                                              AS traede_account,
    CAST(id AS STRING)                                       AS invoice_line_id,
    CAST(invoice_id AS STRING)                               AS invoice_id,
    CAST(product_id AS STRING)                               AS product_id,
    CAST(variant_id AS STRING)                               AS variant_id,

    CAST(quantity AS INT64)                                  AS quantity,
    CAST(net_price AS NUMERIC)                               AS unit_net_price,
    CAST(price_before_discount AS NUMERIC) * CAST(quantity AS INT64) AS line_gross_amount,
    CAST(discount_amount AS NUMERIC) * CAST(quantity AS INT64)       AS line_discount_amount,
    CAST(total_price AS NUMERIC)                             AS line_net_amount,
    CAST(total_price_after_vat AS NUMERIC)                   AS line_total_incl_vat,

    CAST(created_at AS TIMESTAMP)                            AS created_at,
    CAST(updated_at AS TIMESTAMP)                            AS updated_at
FROM {{ source('traede', 'invoice_line') }}
