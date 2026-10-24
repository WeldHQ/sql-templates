-- stg_traede__production_order_line
-- Thin wrapper over raw `production_order_line`. One row per production order
-- line.
--
-- QUANTITIES are buckets of the ordered quantity: in_production (still at the
-- factory), in_delivery (on a delivery note), on_the_way (on a delivery note that
-- has been sent) and received. unit_price is the purchase cost per unit, in the
-- supplier's currency; the stream carries no currency column.

SELECT
    'account_1'                                 AS traede_account,
    CAST(id AS STRING)                          AS production_order_line_id,
    CAST(production_order_id AS STRING)         AS production_order_id,
    CAST(product_id AS STRING)                  AS product_id,
    CAST(variant_id AS STRING)                  AS variant_id,
    CAST(quantity AS INT64)                     AS quantity_ordered,
    CAST(in_production AS INT64)                AS quantity_in_production,
    CAST(in_delivery AS INT64)                  AS quantity_in_delivery,
    CAST(on_the_way AS INT64)                   AS quantity_on_the_way,
    CAST(received AS INT64)                     AS quantity_received,
    CAST(unit_price AS NUMERIC)                 AS unit_cost,
    CAST(total_price AS NUMERIC)                AS line_cost_amount
FROM {{ source('traede', 'production_order_line') }}
