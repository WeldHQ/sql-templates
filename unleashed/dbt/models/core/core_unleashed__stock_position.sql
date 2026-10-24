-- core_unleashed__stock_position
-- Stock on hand, availability, value and slow movers per product, as of the last
-- sync. Unleashed's Stock on Hand report with reorder flags.
-- Grain: product, all warehouses combined.
--
-- The synced stock on hand is summed over warehouses (see
-- staging.unleashed.stock_on_hand), so the flags compare total availability with
-- the product-level alert levels. Value is quantity on hand x average cost, in
-- base currency.

SELECT
    s.product_id,
    s.product_code,
    COALESCE(p.product_description, s.product_description)     AS product_description,
    COALESCE(p.product_group, s.product_group)                 AS product_group,
    p.product_brand,
    p.default_supplier,
    p.is_obsolete,
    s.qty_on_hand,
    s.allocated_qty,
    s.available_qty,
    s.on_purchase_qty,
    s.avg_cost,
    s.total_cost                                               AS stock_value,
    p.min_stock_alert_level,
    p.max_stock_alert_level,
    s.available_qty < p.min_stock_alert_level                  AS is_below_min,
    s.qty_on_hand > p.max_stock_alert_level
        AND p.max_stock_alert_level > 0                        AS is_above_max,
    s.days_since_last_sale,
    CASE
        WHEN s.qty_on_hand <= 0                THEN NULL
        WHEN s.days_since_last_sale IS NULL    THEN 'never_sold'
        WHEN s.days_since_last_sale > 180      THEN 'over_180_days'
        WHEN s.days_since_last_sale > 90       THEN '91_180_days'
        ELSE 'sold_last_90_days'
    END                                                        AS sales_recency_bucket
FROM {{ ref('stg_unleashed__stock_on_hand') }} s
LEFT JOIN {{ ref('stg_unleashed__product') }} p USING (product_id)
