-- core_adobe_commerce__inventory_cover
-- Stock on hand against recent sales: how many days the current stock lasts at
-- the last 30 days' pace. The admin has a Low Stock report; this adds the rate of
-- sale it lacks.
--
-- Grain: store x product x stock x website, as of the last sync. Point in time:
-- the stock table holds current quantities only, so there is no stock history.
-- Materialise it on a daily schedule and keep the runs if you need a trend.
--
-- Sales velocity is counted on the item rows that carry stock. For a configurable
-- product that is the CHILD (simple product) row, not the parent row that
-- sales_over_time and product_sales_over_time read, because stock belongs to the
-- simple product. Configurable, bundle and grouped parents hold no stock and are
-- left out.
--
-- A product with stock rows for several websites gets the same units_sold_30d on
-- each row: velocity is per product, cover is per stock row. Do not sum
-- units_sold_30d across rows.
--
-- Multi-Source Inventory: the legacy stock table holds the default source only.
-- See staging/stock_item.sql.
--
-- Depends on: staging.adobe_commerce.stock_item, .product, .sales_order,
--             .sales_order_item, .store_timezone

WITH today AS (
    SELECT adobe_commerce_store, CURRENT_DATE(report_timezone) AS today, report_timezone
    FROM {{ ref('stg_adobe_commerce__store_timezone') }}
),

units_sold AS (
    SELECT
        i.adobe_commerce_store,
        i.product_id,
        SUM(i.qty_ordered - i.qty_canceled - i.qty_refunded) AS units_sold_30d
    FROM {{ ref('stg_adobe_commerce__sales_order_item') }} i
    JOIN {{ ref('stg_adobe_commerce__sales_order') }} o USING (adobe_commerce_store, order_id)
    JOIN today t ON t.adobe_commerce_store = i.adobe_commerce_store
    WHERE i.product_type NOT IN ('configurable', 'bundle', 'grouped')
      AND o.state NOT IN ('new', 'pending_payment', 'canceled')
      AND DATE(o.created_at, t.report_timezone) >  DATE_SUB(t.today, INTERVAL 30 DAY)
      AND DATE(o.created_at, t.report_timezone) <= t.today
    GROUP BY i.adobe_commerce_store, i.product_id
)

SELECT
    s.adobe_commerce_store,
    s.product_id,
    p.sku,
    p.product_type,
    s.stock_id,
    s.website_id,
    s.qty,
    s.is_in_stock,
    s.manages_stock,
    s.allows_backorders,
    s.notify_stock_qty,
    s.qty <= COALESCE(s.notify_stock_qty, 1) AS is_low_stock,
    COALESCE(u.units_sold_30d, 0)            AS units_sold_30d,
    ROUND(COALESCE(u.units_sold_30d, 0) / 30, 2) AS avg_daily_units_30d,
    -- NULL when nothing sold: infinite cover is not a number worth charting.
    ROUND(SAFE_DIVIDE(s.qty, NULLIF(COALESCE(u.units_sold_30d, 0), 0) / 30), 1) AS days_of_cover
FROM {{ ref('stg_adobe_commerce__stock_item') }} s
LEFT JOIN {{ ref('stg_adobe_commerce__product') }} p USING (adobe_commerce_store, product_id)
LEFT JOIN units_sold u USING (adobe_commerce_store, product_id)
WHERE COALESCE(p.product_type, 'simple') NOT IN ('configurable', 'bundle', 'grouped')
