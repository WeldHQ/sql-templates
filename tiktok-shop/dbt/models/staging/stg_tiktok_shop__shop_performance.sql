-- stg_tiktok_shop__shop_performance
-- Thin wrapper over raw `shop_performance`: TikTok's own shop analytics, one row
-- per shop per day (the connector requests daily intervals).
--
-- These are TikTok's numbers, computed by TikTok, in the shop's local day. They
-- are only available for shops in the US, UK, Singapore, Vietnam and Thailand;
-- elsewhere the table stays empty. The latest days restate as TikTok finalises
-- them, so the latest sync per day wins.

SELECT
    'account_1'                              AS tiktok_account,
    CAST(shop_id AS STRING)                  AS shop_id,
    CAST(start_date AS DATE)                 AS date,
    UPPER(CAST(gmv_currency AS STRING))      AS currency,
    CAST(gmv_amount AS NUMERIC)              AS gmv,
    CAST(orders AS INT64)                    AS orders,
    CAST(sku_orders AS INT64)                AS sku_orders,
    CAST(units_sold AS INT64)                AS units_sold,
    CAST(buyers AS INT64)                    AS buyers,
    CAST(avg_order_value_amount AS NUMERIC)  AS avg_order_value,
    CAST(refunds_amount AS NUMERIC)          AS refunds,
    CAST(cancellations_and_returns AS INT64) AS cancellations_and_returns,
    CAST(product_impressions AS INT64)       AS product_impressions,
    CAST(product_page_views AS INT64)        AS product_page_views,
    CAST(avg_product_page_visitors AS INT64) AS avg_product_page_visitors
FROM {{ source('tiktok_shop', 'shop_performance') }}
WHERE start_date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY shop_id, start_date ORDER BY _weld_synced DESC) = 1
