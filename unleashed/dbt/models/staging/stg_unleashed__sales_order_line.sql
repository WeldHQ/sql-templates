-- stg_unleashed__sales_order_line
-- Thin wrapper over raw `sales_order_line`. One row per sales order line.
--
-- bc_line_total is the line value after discount, before tax, in base currency.
-- average_landed_price_at_time_of_sale is the product's average landed cost per
-- unit when the order was completed, also in base currency: Unleashed's own basis
-- for cost of goods sold and gross margin.

SELECT
    CAST(guid AS STRING)                                    AS sales_order_line_id,
    CAST(sales_order_guid AS STRING)                        AS sales_order_id,
    CAST(line_number AS INT64)                              AS line_number,
    CAST(line_type AS STRING)                               AS line_type,
    CAST(product_guid AS STRING)                            AS product_id,
    CAST(product_product_code AS STRING)                    AS product_code,
    CAST(product_product_description AS STRING)             AS product_description,
    CAST(order_quantity AS FLOAT64)                         AS quantity,
    CAST(unit_price AS FLOAT64)                             AS unit_price,
    CAST(discount_rate AS FLOAT64)                          AS discount_rate,
    CAST(line_total AS FLOAT64)                             AS line_total,
    CAST(bc_line_total AS FLOAT64)                          AS bc_line_total,
    CAST(average_landed_price_at_time_of_sale AS FLOAT64)   AS unit_landed_cost
FROM {{ source('unleashed', 'sales_order_line') }}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(last_modified_on AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
