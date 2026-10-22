-- core_tiktok_organic__profile_performance_daily
-- The TikTok Analytics Overview per account per day: followers, net follower
-- change, profile views, video views, likes, comments, shares and engagement
-- rate.
--
-- Grain: date_day x business_id. Days are UTC.
-- Depends on: staging.tiktok_organic.profile_metrics, .profile
--
-- FOLLOWERS IS A RUNNING TOTAL: take the last day of a period, never the sum.
-- follower_change is the difference from the previous day that has a follower
-- count. A follower count of 0 is treated as "not yet processed" (TikTok
-- reports unprocessed days as 0) and left NULL, so it does not show as a
-- collapse and recovery.
--
-- engagement_rate = (likes + comments + shares) / video_views for the day. To
-- roll up, divide summed engagements by summed video_views.

WITH daily AS (
    SELECT
        date_day,
        business_id,
        NULLIF(followers, 0) AS followers,
        profile_views,
        video_views,
        likes,
        comments,
        shares
    FROM {{ ref('stg_tiktok_organic__profile_metrics') }}
    WHERE date_day IS NOT NULL
)

SELECT
    d.date_day,
    d.business_id,
    p.username,
    p.display_name,
    d.followers,
    d.followers - LAST_VALUE(d.followers IGNORE NULLS) OVER (
        PARTITION BY d.business_id ORDER BY d.date_day
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    )                                                         AS follower_change,
    d.profile_views,
    d.video_views,
    d.likes,
    d.comments,
    d.shares,
    d.likes + d.comments + d.shares                           AS engagements,
    SAFE_DIVIDE(d.likes + d.comments + d.shares, d.video_views) AS engagement_rate
FROM daily d
-- One row per account after staging, so this cannot fan out.
LEFT JOIN {{ ref('stg_tiktok_organic__profile') }} p USING (business_id)
