-- staging.unleashed.stock_on_hand
-- Thin wrapper over raw `stock_on_hand`. One row per product, latest version.
-- Unleashed's Stock on Hand: quantities and average cost now.
--
-- The connector calls Unleashed's StockOnHand list without a warehouse filter,
-- which returns each product's stock summed over all warehouses with the
-- warehouse fields left empty. The raw key `guid` is the product guid. Per
-- warehouse stock would need the endpoint called once per warehouse.
--
-- avg_cost and total_cost are in base currency. available_qty is on hand minus
-- allocated to sales orders.

SELECT
    CAST(product_guid AS STRING)        AS product_id,
    CAST(product_code AS STRING)        AS product_code,
    CAST(product_description AS STRING) AS product_description,
    CAST(product_group_name AS STRING)  AS product_group,
    CAST(qty_on_hand AS FLOAT64)        AS qty_on_hand,
    CAST(allocated_qty AS FLOAT64)      AS allocated_qty,
    CAST(available_qty AS FLOAT64)      AS available_qty,
    CAST(on_purchase AS FLOAT64)        AS on_purchase_qty,
    CAST(avg_cost AS FLOAT64)           AS avg_cost,
    CAST(total_cost AS FLOAT64)         AS total_cost,
    CAST(days_since_last_sale AS INT64) AS days_since_last_sale,
    CAST(last_modified_on AS TIMESTAMP) AS last_modified_on
FROM {{raw.unleashed.stock_on_hand}}
WHERE product_guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(product_guid AS STRING)
    ORDER BY CAST(last_modified_on AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
