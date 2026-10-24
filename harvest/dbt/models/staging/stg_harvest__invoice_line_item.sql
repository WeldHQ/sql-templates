-- stg_harvest__invoice_line_item
-- Thin wrapper over raw `invoice_line_items`. One row per invoice line.
-- `amount` is quantity x unit price, before tax, in the invoice currency.

SELECT
    CAST(id AS STRING)          AS invoice_line_item_id,
    CAST(invoice_id AS STRING)  AS invoice_id,
    CAST(project_id AS STRING)  AS project_id,
    LOWER(CAST(kind AS STRING)) AS kind,
    CAST(quantity AS FLOAT64)   AS quantity,
    CAST(unit_price AS FLOAT64) AS unit_price,
    CAST(amount AS FLOAT64)     AS amount
FROM {{ source('harvest', 'invoice_line_items') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY _weld_synced DESC) = 1
