-- stg_adobe_commerce__sales_order_item
-- One row per order item. Composite products are stored as a parent row plus
-- child rows (parent_item_id points at the parent):
--   * configurable: the parent row carries the price and the chosen simple
--     product's SKU; the child row is the simple product with no price of its own.
--   * bundle: the parent row is the bundle, children are its components.
-- Core decides which rows to read; staging only flags them (is_top_level).
--
-- Money in base currency, NULL as 0. Item discounts are positive magnitudes
-- (unlike the order row). base_amount_refunded is the refunded row value BEFORE
-- discount; base_discount_refunded is the discount given back with it.
-- base_cost is the unit cost Magento copied from the product's cost attribute when
-- the order was placed, NULL when no cost was set.

SELECT
    'store_1'                                    AS adobe_commerce_store,
    CAST(item_id AS INT64)                       AS item_id,
    CAST(order_id AS INT64)                      AS order_id,
    CAST(parent_item_id AS INT64)                AS parent_item_id,
    parent_item_id IS NULL                       AS is_top_level,
    CAST(product_id AS INT64)                    AS product_id,
    CAST(product_type AS STRING)                 AS product_type,
    CAST(sku AS STRING)                          AS sku,
    NULLIF(TRIM(CAST(name AS STRING)), '')       AS product_name,
    CAST(created_at AS TIMESTAMP)                AS created_at,
    COALESCE(CAST(qty_ordered AS NUMERIC), 0)    AS qty_ordered,
    COALESCE(CAST(qty_canceled AS NUMERIC), 0)   AS qty_canceled,
    COALESCE(CAST(qty_invoiced AS NUMERIC), 0)   AS qty_invoiced,
    COALESCE(CAST(qty_refunded AS NUMERIC), 0)   AS qty_refunded,
    COALESCE(CAST(qty_shipped AS NUMERIC), 0)    AS qty_shipped,
    COALESCE(CAST(base_price AS NUMERIC), 0)     AS base_price,
    CAST(base_cost AS NUMERIC)                   AS base_cost,
    COALESCE(CAST(base_row_total AS NUMERIC), 0) AS base_row_total,
    ABS(COALESCE(CAST(base_discount_amount AS NUMERIC), 0))   AS base_discount_amount,
    ABS(COALESCE(CAST(base_discount_refunded AS NUMERIC), 0)) AS base_discount_refunded,
    COALESCE(CAST(base_tax_amount AS NUMERIC), 0)       AS base_tax_amount,
    COALESCE(CAST(base_tax_refunded AS NUMERIC), 0)     AS base_tax_refunded,
    COALESCE(CAST(base_amount_refunded AS NUMERIC), 0)  AS base_amount_refunded
FROM {{ source('adobe_commerce', 'sales_order_item') }}
QUALIFY ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY _weld_synced DESC) = 1
