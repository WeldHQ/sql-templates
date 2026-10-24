-- core_tiktok_organic__video_performance
-- The TikTok Analytics Content tab: every video with its lifetime views, reach,
-- likes, comments, shares, watch time, completion rate and engagement rate.
--
-- Grain: one row per video. Metrics are lifetime totals as of `metrics_as_of`,
-- the last sync, and keep growing while a video gets views, so this is a
-- snapshot, not a time series.
-- Depends on: staging.tiktok_organic.video, .profile
--
-- engagement_rate = (likes + comments + shares) / video_views, the usual TikTok
-- definition. engagement_rate_by_reach divides by unique viewers instead. To roll
-- up a set of videos, divide summed engagements by summed video_views; reach is
-- unique per video, so summed reach over videos counts a person once per video.

SELECT
    v.video_id,
    v.business_id,
    p.username,
    v.created_at,
    DATE(v.created_at)                                          AS created_date,
    v.caption,
    v.share_url,
    v.thumbnail_url,
    v.duration_seconds,
    v.synced_at                                                 AS metrics_as_of,
    v.video_views,
    v.reach,
    v.likes,
    v.comments,
    v.shares,
    v.likes + v.comments + v.shares                             AS engagements,
    SAFE_DIVIDE(v.likes + v.comments + v.shares, v.video_views) AS engagement_rate,
    SAFE_DIVIDE(v.likes + v.comments + v.shares, v.reach)       AS engagement_rate_by_reach,
    v.total_time_watched_seconds,
    v.average_time_watched_seconds,
    SAFE_DIVIDE(v.average_time_watched_seconds, v.duration_seconds) AS average_share_watched,
    v.full_video_watched_rate
FROM {{ ref('stg_tiktok_organic__video') }} v
-- One row per account after staging, so this cannot fan out.
LEFT JOIN {{ ref('stg_tiktok_organic__profile') }} p USING (business_id)
