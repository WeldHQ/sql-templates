-- staging.google_search_console.site_analytics
-- Thin wrapper over raw `site_analytics_web`. Casts and renames. No other logic.
--
-- Grain: site x date x country x device, aggregated by property. This is the
-- table that matches the totals on the Search Console Performance report.
-- Web search only. To add image, video or news results, UNION ALL the matching
-- `_image`, `_video` or `_news` table; `search_type` keeps them apart.
--
-- The connector upserts on its primary key (site plus every dimension) and
-- re-reads the last three days on each sync, so rows do not repeat.

SELECT
    CAST(site AS STRING)                     AS site,
    CAST(date AS DATE)                       AS date_day,
    LOWER(CAST(country AS STRING))           AS country,
    LOWER(CAST(device AS STRING))            AS device,
    CAST(search_type AS STRING)              AS search_type,
    CAST(COALESCE(clicks, 0) AS INT64)       AS clicks,
    CAST(COALESCE(impressions, 0) AS INT64)  AS impressions,
    -- Google's average position for the row, 1 = top. Kept so core can weight it
    -- by impressions; never average it unweighted.
    CAST(position AS FLOAT64)                AS position
FROM {{raw.google_search_console.site_analytics_web}}
