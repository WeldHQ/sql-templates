-- core_app_store_connect__product_page_conversion
-- The App Store funnel: impressions, product page views, taps on Get, and the
-- downloads that followed, by where people found the app. App Analytics' Sources
-- view, with conversion recomputed at any grain.
--
-- Grain: one row per day x app x territory x source type x device.
-- Depends on: staging.app_store_connect.store_engagement,
--             core.app_store_connect.downloads_and_deletions
--
-- APPLE'S CONVERSION RATE USES UNIQUE IMPRESSIONS; THIS ONE USES IMPRESSIONS.
-- Unique counts are distinct users within one row of Apple's file and cannot be
-- added up across devices, territories or days, so a unique-based rate can only be
-- shown at exactly Apple's grain. `downloads_per_impression` divides summed counts
-- instead. It is lower than the App Store Connect figure, consistently so, and it
-- stays correct when you roll it up. Compare trends, not the level.
--
-- Impressions are counted on event = 'Impression' across all engagement types;
-- page views on event = 'Page view'. Apple counts impressions and page views
-- separately: a page view is not also an impression.

WITH engagement AS (
    SELECT
        date_day,
        app_apple_id,
        ANY_VALUE(app_name)                                                     AS app_name,
        territory,
        source_type,
        device,
        SUM(IF(event = 'Impression', event_count, 0))                           AS impressions,
        SUM(IF(event = 'Page view', event_count, 0))                            AS product_page_views,
        SUM(IF(event = 'Tap' AND engagement_type = 'Get', event_count, 0))      AS get_taps
    FROM {{ ref('stg_app_store_connect__store_engagement') }}
    GROUP BY date_day, app_apple_id, territory, source_type, device
)

SELECT
    COALESCE(e.date_day, d.date_day)            AS date_day,
    COALESCE(e.app_apple_id, d.app_apple_id)    AS app_apple_id,
    COALESCE(e.app_name, d.app_name)            AS app_name,
    COALESCE(e.territory, d.territory)          AS territory,
    COALESCE(e.source_type, d.source_type)      AS source_type,
    COALESCE(e.device, d.device)                AS device,

    COALESCE(e.impressions, 0)                  AS impressions,
    COALESCE(e.product_page_views, 0)           AS product_page_views,
    COALESCE(e.get_taps, 0)                     AS get_taps,
    COALESCE(d.first_time_downloads, 0)         AS first_time_downloads,
    COALESCE(d.redownloads, 0)                  AS redownloads,

    ROUND(SAFE_DIVIDE(e.product_page_views, NULLIF(e.impressions, 0)), 4)                   AS page_views_per_impression,
    ROUND(SAFE_DIVIDE(d.first_time_downloads + d.redownloads, NULLIF(e.impressions, 0)), 4) AS downloads_per_impression,
    ROUND(SAFE_DIVIDE(d.first_time_downloads + d.redownloads, NULLIF(e.product_page_views, 0)), 4) AS downloads_per_page_view
FROM engagement e
FULL OUTER JOIN {{ ref('core_app_store_connect__downloads_and_deletions') }} d
  ON  d.date_day     = e.date_day
  AND d.app_apple_id = e.app_apple_id
  AND d.territory    = e.territory
  AND d.source_type  = e.source_type
  AND d.device       = e.device
