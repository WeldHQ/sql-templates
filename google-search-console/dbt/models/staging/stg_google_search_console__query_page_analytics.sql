-- stg_google_search_console__query_page_analytics
-- Thin wrapper over raw `keyword_page_analytics_web`. Casts and renames. No other logic.
--
-- Grain: site x date x country x device x page x query, aggregated by page.
-- Anonymized queries are dropped here too, and a query that shows two of your
-- pages counts an impression on each, so this does not sum to site_analytics.
-- Web search only. To add image, video or news results, UNION ALL the matching
-- `_image`, `_video` or `_news` table; `search_type` keeps them apart.
--
-- The connector upserts on its primary key (site plus every dimension) and
-- re-reads the last three days on each sync, so rows do not repeat.

SELECT
    CAST(site AS STRING)                     AS site,
    CAST(date AS DATE)                       AS date_day,
    CAST(page AS STRING)                     AS page,
    CAST(query AS STRING)                    AS query,
    LOWER(CAST(country AS STRING))           AS country,
    LOWER(CAST(device AS STRING))            AS device,
    CAST(search_type AS STRING)              AS search_type,
    CAST(COALESCE(clicks, 0) AS INT64)       AS clicks,
    CAST(COALESCE(impressions, 0) AS INT64)  AS impressions,
    -- Google's average position for the row, 1 = top. Kept so core can weight it
    -- by impressions; never average it unweighted.
    CAST(position AS FLOAT64)                AS position
FROM {{ source('google_search_console', 'keyword_page_analytics_web') }}
