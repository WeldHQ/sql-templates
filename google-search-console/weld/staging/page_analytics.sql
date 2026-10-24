-- staging.google_search_console.page_analytics
-- Thin wrapper over raw `page_analytics_web`. Casts and renames. No other logic.
--
-- Grain: site x date x country x device x page, aggregated by page.
-- Web search only. To add image, video or news results, UNION ALL the matching
-- `_image`, `_video` or `_news` table; `search_type` keeps them apart.
--
-- The raw table has one row per site and every dimension, and the last three
-- days are re-read on each sync, so rows do not repeat.

SELECT
    CAST(site AS STRING)                     AS site,
    CAST(date AS DATE)                       AS date_day,
    CAST(page AS STRING)                     AS page,
    LOWER(CAST(country AS STRING))           AS country,
    LOWER(CAST(device AS STRING))            AS device,
    CAST(search_type AS STRING)              AS search_type,
    CAST(COALESCE(clicks, 0) AS INT64)       AS clicks,
    CAST(COALESCE(impressions, 0) AS INT64)  AS impressions,
    -- Google's average position for the row, 1 = top. Kept so core can weight it
    -- by impressions; never average it unweighted.
    CAST(position AS FLOAT64)                AS position
FROM {{raw.google_search_console.page_analytics_web}}
