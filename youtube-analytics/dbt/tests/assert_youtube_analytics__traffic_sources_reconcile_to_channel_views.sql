-- The traffic source report and the user activity report split the same views
-- in different ways, so per channel and month their totals should agree. YouTube
-- applies privacy thresholds per report, so allow 1% of drift before failing.

WITH channel AS (
    SELECT DATE_TRUNC(date_day, MONTH) AS month, channel_id, SUM(views) AS views
    FROM {{ ref('core_youtube_analytics__channel_performance_daily') }}
    GROUP BY 1, 2
),

sources AS (
    SELECT DATE_TRUNC(date_day, MONTH) AS month, channel_id, SUM(views) AS views
    FROM {{ ref('core_youtube_analytics__traffic_sources_daily') }}
    GROUP BY 1, 2
)

SELECT c.month, c.channel_id, c.views AS channel_views, s.views AS traffic_source_views
FROM channel c
JOIN sources s USING (month, channel_id)
WHERE ABS(c.views - s.views) > 0.01 * GREATEST(c.views, s.views)
