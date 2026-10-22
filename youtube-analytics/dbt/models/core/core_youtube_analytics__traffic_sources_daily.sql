-- core_youtube_analytics__traffic_sources_daily
-- Where views come from: YouTube search, suggested videos, browse, Shorts feed,
-- external sites and so on. The YouTube Studio "Traffic source types" report.
--
-- Grain: date_day x channel_id x traffic_source_type. Dates are Pacific Time.
-- Depends on: staging.youtube_analytics.channel_traffic_source
--
-- share_of_views is the source's share of the channel's views that day. For a
-- longer period re-sum views and divide again.

SELECT
    date_day,
    channel_id,
    traffic_source_type,
    traffic_source,
    SUM(views)                  AS views,
    SUM(engaged_views)          AS engaged_views,
    SUM(watch_time_minutes)     AS watch_time_minutes,
    SAFE_DIVIDE(SUM(watch_time_minutes) * 60, SUM(views)) AS average_view_duration_seconds,
    COUNT(DISTINCT video_id)    AS videos,
    SAFE_DIVIDE(SUM(views), SUM(SUM(views)) OVER (PARTITION BY date_day, channel_id)) AS share_of_views
FROM {{ ref('stg_youtube_analytics__channel_traffic_source') }}
GROUP BY 1, 2, 3, 4
