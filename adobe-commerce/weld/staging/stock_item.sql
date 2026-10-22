-- staging.adobe_commerce.stock_item
-- Current stock per product from the legacy inventory table. One row per product,
-- stock and website (website_id 0 is the global default stock).
--
-- With Multi-Source Inventory (Adobe Commerce 2.3+) this table still holds the
-- default source's quantity, which is the whole story for a single-source store.
-- Stores with several sources keep the per-source quantities in
-- inventory_source_item, which is not synced; for them qty here understates stock.

SELECT
    'store_1'                                  AS adobe_commerce_store,
    CAST(item_id AS INT64)                     AS stock_item_id,
    CAST(product_id AS INT64)                  AS product_id,
    CAST(stock_id AS INT64)                    AS stock_id,
    CAST(website_id AS INT64)                  AS website_id,
    COALESCE(CAST(qty AS NUMERIC), 0)          AS qty,
    COALESCE(CAST(is_in_stock AS INT64), 0) = 1 AS is_in_stock,
    -- use_config_manage_stock = 1 means "follow the global setting", which is
    -- Yes by default; only an explicit per-product No turns tracking off.
    CASE
        WHEN COALESCE(CAST(use_config_manage_stock AS INT64), 1) = 1 THEN TRUE
        ELSE COALESCE(CAST(manage_stock AS INT64), 1) = 1
    END                                        AS manages_stock,
    CAST(notify_stock_qty AS NUMERIC)          AS notify_stock_qty,
    COALESCE(CAST(backorders AS INT64), 0) > 0 AS allows_backorders
FROM {{raw.adobe_commerce.cataloginventory_stock_item}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY _weld_synced DESC) = 1
