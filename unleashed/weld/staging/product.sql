-- staging.unleashed.product
-- Thin wrapper over raw `product`. One row per product, latest version, obsolete
-- products included and flagged.

SELECT
    CAST(guid AS STRING)                        AS product_id,
    CAST(product_code AS STRING)                AS product_code,
    CAST(product_description AS STRING)         AS product_description,
    CAST(product_group_group_name AS STRING)    AS product_group,
    CAST(product_brand_brand_name AS STRING)    AS product_brand,
    CAST(supplier_supplier_name AS STRING)      AS default_supplier,
    CAST(min_stock_alert_level AS FLOAT64)      AS min_stock_alert_level,
    CAST(max_stock_alert_level AS FLOAT64)      AS max_stock_alert_level,
    CAST(default_sell_price AS FLOAT64)         AS default_sell_price,
    CAST(average_land_price AS FLOAT64)         AS average_land_price,
    COALESCE(obsolete, FALSE)                   AS is_obsolete,
    COALESCE(is_sellable, FALSE)                AS is_sellable
FROM {{raw.unleashed.product}}
WHERE guid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(guid AS STRING)
    ORDER BY CAST(last_modified_on AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
