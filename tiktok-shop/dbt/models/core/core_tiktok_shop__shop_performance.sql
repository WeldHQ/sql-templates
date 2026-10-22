-- core_tiktok_shop__shop_performance
-- TikTok's own shop analytics per day, on a continuous date spine, with the
-- ratios Seller Center shows recomputed from their parts.
--
-- Grain: day x account x shop. Days TikTok reported nothing for appear with
-- zeros, so a chart of a quiet shop does not silently skip days.
--
-- WHAT IT IS FOR. These are TikTok's numbers, not rebuilt ones: GMV, orders,
-- units, buyers, page views. Use them as the reference that
-- core.tiktok_shop.sales_over_time is reconciled against, and for the traffic
-- metrics no order table carries. GMV follows TikTok's own definition, which is
-- not the same as net_sales here (it is not reduced by the refunds that land on
-- later days), so expect the two to differ and compare trends, not single days.
--
-- Only shops in the US, UK, Singapore, Vietnam and Thailand get this data from
-- TikTok. avg_product_page_visitors is a daily average and is not summed.
--
-- Depends on: staging.tiktok_shop.shop_performance

WITH perf AS (
    SELECT * FROM {{ ref('stg_tiktok_shop__shop_performance') }}
),

bounds AS (
    SELECT tiktok_account, shop_id, MIN(date) AS first_date, MAX(date) AS last_date,
           ANY_VALUE(currency) AS currency
    FROM perf
    GROUP BY tiktok_account, shop_id
),

spine AS (
    SELECT b.tiktok_account, b.shop_id, b.currency, d AS date
    FROM bounds b, UNNEST(GENERATE_DATE_ARRAY(b.first_date, b.last_date)) AS d
)

SELECT
    s.date,
    s.tiktok_account,
    s.shop_id,
    COALESCE(p.currency, s.currency)               AS currency,
    ROUND(COALESCE(p.gmv, 0), 2)                   AS gmv,
    COALESCE(p.orders, 0)                          AS orders,
    COALESCE(p.sku_orders, 0)                      AS sku_orders,
    COALESCE(p.units_sold, 0)                      AS units_sold,
    COALESCE(p.buyers, 0)                          AS buyers,
    ROUND(COALESCE(p.refunds, 0), 2)               AS refunds,
    COALESCE(p.cancellations_and_returns, 0)       AS cancellations_and_returns,
    COALESCE(p.product_impressions, 0)             AS product_impressions,
    COALESCE(p.product_page_views, 0)              AS product_page_views,
    p.avg_product_page_visitors,
    -- Ratios from parts, so they can be re-aggregated correctly in BI as
    -- SUM(gmv) / SUM(orders) rather than averaged.
    ROUND(SAFE_DIVIDE(p.gmv, p.orders), 2)         AS avg_order_value,
    SAFE_DIVIDE(p.orders, p.product_page_views)    AS orders_per_page_view
FROM spine s
LEFT JOIN perf p
       ON  p.tiktok_account = s.tiktok_account
       AND p.shop_id        = s.shop_id
       AND p.date           = s.date
