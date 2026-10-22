-- core_youtube_analytics__channel_performance_daily
-- Channel totals per day: views, watch time, engagement, subscriber movement and
-- thumbnail reach. The YouTube Studio channel overview, by day.
--
-- Grain: date_day x channel_id. Dates are Pacific Time.
-- Depends on: staging.youtube_analytics.channel_basic, core.youtube_analytics.video_performance_daily
--
-- Subscribers are read from the activity report directly, not summed from
-- videos: YouTube puts subscriptions that happen off a watch page (channel page,
-- home feed) on rows with no video, and those would be lost in a video roll-up.
-- `subscribers_off_video` shows how many that is.

WITH channel_subs AS (
    SELECT
        date_day,
        channel_id,
        SUM(subscribers_gained)                              AS subscribers_gained,
        SUM(subscribers_lost)                                AS subscribers_lost,
        SUM(IF(video_id IS NULL, subscribers_gained - subscribers_lost, 0)) AS subscribers_off_video
    FROM {{ ref('stg_youtube_analytics__channel_basic') }}
    GROUP BY 1, 2
),

videos AS (
    SELECT
        date_day,
        channel_id,
        SUM(views)                      AS views,
        SUM(engaged_views)              AS engaged_views,
        SUM(premium_views)              AS premium_views,
        SUM(live_views)                 AS live_views,
        SUM(views_from_subscribers)     AS views_from_subscribers,
        SUM(watch_time_minutes)         AS watch_time_minutes,
        SUM(view_percentage_weighted)   AS view_percentage_weighted,
        SUM(likes)                      AS likes,
        SUM(dislikes)                   AS dislikes,
        SUM(comments)                   AS comments,
        SUM(shares)                     AS shares,
        SUM(thumbnail_impressions)      AS thumbnail_impressions,
        SUM(thumbnail_ctr_weighted)     AS thumbnail_ctr_weighted,
        COUNTIF(views > 0)              AS videos_viewed
    FROM {{ ref('core_youtube_analytics__video_performance_daily') }}
    GROUP BY 1, 2
)

SELECT
    COALESCE(v.date_day, s.date_day)     AS date_day,
    COALESCE(v.channel_id, s.channel_id) AS channel_id,
    COALESCE(v.views, 0)                 AS views,
    COALESCE(v.engaged_views, 0)         AS engaged_views,
    COALESCE(v.premium_views, 0)         AS premium_views,
    COALESCE(v.live_views, 0)            AS live_views,
    COALESCE(v.views_from_subscribers, 0) AS views_from_subscribers,
    COALESCE(v.watch_time_minutes, 0)    AS watch_time_minutes,
    SAFE_DIVIDE(v.watch_time_minutes, 60)                   AS watch_time_hours,
    SAFE_DIVIDE(v.watch_time_minutes * 60, v.views)         AS average_view_duration_seconds,
    SAFE_DIVIDE(v.view_percentage_weighted, v.views)        AS average_percentage_viewed,
    COALESCE(v.likes, 0)                 AS likes,
    COALESCE(v.dislikes, 0)              AS dislikes,
    COALESCE(v.comments, 0)              AS comments,
    COALESCE(v.shares, 0)                AS shares,
    COALESCE(s.subscribers_gained, 0)    AS subscribers_gained,
    COALESCE(s.subscribers_lost, 0)      AS subscribers_lost,
    COALESCE(s.subscribers_gained, 0) - COALESCE(s.subscribers_lost, 0) AS net_subscribers,
    COALESCE(s.subscribers_off_video, 0) AS subscribers_off_video,
    COALESCE(v.thumbnail_impressions, 0) AS thumbnail_impressions,
    SAFE_DIVIDE(v.thumbnail_ctr_weighted, v.thumbnail_impressions) AS thumbnail_ctr,
    COALESCE(v.videos_viewed, 0)         AS videos_viewed
FROM videos v
FULL OUTER JOIN channel_subs s
  ON  s.date_day   = v.date_day
  AND s.channel_id = v.channel_id
