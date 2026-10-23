-- core.youtube_analytics.video_performance_daily
-- Per-video views, watch time, engagement, subscribers and thumbnail reach, the
-- YouTube Studio "Content" tab by day.
--
-- Grain: date_day x channel_id x video_id. Dates are Pacific Time, as YouTube
-- reports them.
-- Depends on: staging.youtube_analytics.channel_basic, .channel_reach
--
-- Averages are recomputed from sums: average view duration is watch time over
-- views, and average percentage viewed is weighted by views. average_percentage_viewed
-- stays on YouTube's 0 to 100 scale, as Studio shows it. To report a week or
-- a month, re-sum the base columns and divide again. The *_weighted columns are
-- there for exactly that.
--
-- The Reporting API carries no video titles. Join a video list of your own on
-- video_id if you need them.

WITH activity AS (
    SELECT
        date_day,
        channel_id,
        video_id,
        SUM(views)                       AS views,
        SUM(engaged_views)               AS engaged_views,
        SUM(premium_views)               AS premium_views,
        SUM(watch_time_minutes)          AS watch_time_minutes,
        SUM(average_view_duration_percentage * views) AS view_percentage_weighted,
        SUM(subscribers_gained)          AS subscribers_gained,
        SUM(subscribers_lost)            AS subscribers_lost,
        SUM(likes)                       AS likes,
        SUM(dislikes)                    AS dislikes,
        SUM(shares)                      AS shares,
        SUM(comments)                    AS comments,
        SUM(IF(subscribed_status = 'subscribed', views, 0)) AS views_from_subscribers,
        SUM(IF(live_or_on_demand = 'live', views, 0))       AS live_views
    FROM {{staging.youtube_analytics.channel_basic}}
    WHERE video_id IS NOT NULL
    GROUP BY 1, 2, 3
),

reach AS (
    SELECT
        date_day,
        channel_id,
        video_id,
        SUM(thumbnail_impressions)                   AS thumbnail_impressions,
        SUM(thumbnail_impressions * thumbnail_ctr)   AS thumbnail_ctr_weighted
    FROM {{staging.youtube_analytics.channel_reach}}
    WHERE video_id IS NOT NULL
    GROUP BY 1, 2, 3
)

SELECT
    COALESCE(a.date_day, r.date_day)     AS date_day,
    COALESCE(a.channel_id, r.channel_id) AS channel_id,
    COALESCE(a.video_id, r.video_id)     AS video_id,

    COALESCE(a.views, 0)                 AS views,
    COALESCE(a.engaged_views, 0)         AS engaged_views,
    COALESCE(a.premium_views, 0)         AS premium_views,
    COALESCE(a.live_views, 0)            AS live_views,
    COALESCE(a.views_from_subscribers, 0) AS views_from_subscribers,
    COALESCE(a.watch_time_minutes, 0)    AS watch_time_minutes,
    SAFE_DIVIDE(a.watch_time_minutes * 60, a.views)        AS average_view_duration_seconds,
    SAFE_DIVIDE(a.view_percentage_weighted, a.views)       AS average_percentage_viewed,
    a.view_percentage_weighted,

    COALESCE(a.likes, 0)                 AS likes,
    COALESCE(a.dislikes, 0)              AS dislikes,
    COALESCE(a.comments, 0)              AS comments,
    COALESCE(a.shares, 0)                AS shares,
    COALESCE(a.subscribers_gained, 0)    AS subscribers_gained,
    COALESCE(a.subscribers_lost, 0)      AS subscribers_lost,
    COALESCE(a.subscribers_gained, 0) - COALESCE(a.subscribers_lost, 0) AS net_subscribers,

    COALESCE(r.thumbnail_impressions, 0) AS thumbnail_impressions,
    SAFE_DIVIDE(r.thumbnail_ctr_weighted, r.thumbnail_impressions) AS thumbnail_ctr,
    r.thumbnail_ctr_weighted
FROM activity a
-- Both sides are pre-aggregated to the same grain, so this is one to one. FULL
-- OUTER: a video can have impressions and no views on a day, or the reverse.
FULL OUTER JOIN reach r
  ON  r.date_day   = a.date_day
  AND r.channel_id = a.channel_id
  AND r.video_id   = a.video_id
