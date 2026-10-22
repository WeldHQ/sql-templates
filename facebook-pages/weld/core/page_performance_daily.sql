-- core.facebook_pages.page_performance_daily
-- The Facebook Page Insights overview per Page per day: followers, new likes,
-- views and viewers of the Page's content, engagement, Page visits and video
-- views.
--
-- Grain: date_day x page_id. Days are Pacific Time, as Page Insights shows them.
-- Depends on: staging.facebook_pages.page_daily_insights, .page
--
-- FOLLOWERS IS A RUNNING TOTAL. page_follows is the follower count at the end of
-- the day, so `followers` must never be summed across days; follower_change is
-- the day over day difference. Every other metric here counts the day itself and
-- can be summed, except `viewers`, which is unique people per day.
--
-- VIEWS REPLACED IMPRESSIONS. Meta removed Page impressions and reach from the
-- API on 15 June 2026 and replaced them with views (page_media_view) and viewers
-- (page_total_media_view_unique). post_impressions_legacy and post_reach_legacy
-- carry the old metrics for the days before that and stay NULL afterwards; views
-- and impressions are counted differently, so do not splice them into one series.

WITH pivoted AS (
    SELECT
        page_id,
        date_day,
        MAX(IF(metric = 'page_follows' AND breakdown IS NULL, value, NULL))                                AS followers,
        SUM(IF(metric = 'page_fan_adds_by_paid_non_paid_unique' AND breakdown = 'total', value, 0))        AS new_likes,
        SUM(IF(metric = 'page_fan_adds_by_paid_non_paid_unique' AND breakdown = 'paid', value, 0))         AS new_likes_paid,
        SUM(IF(metric = 'page_fan_adds_by_paid_non_paid_unique' AND breakdown = 'unpaid', value, 0))       AS new_likes_organic,
        MAX(IF(metric = 'page_media_view' AND breakdown IS NULL, value, NULL))                             AS views,
        MAX(IF(metric = 'page_total_media_view_unique' AND breakdown IS NULL, value, NULL))                AS viewers,
        SUM(IF(metric = 'page_post_engagements' AND breakdown IS NULL, value, 0))                          AS post_engagements,
        SUM(IF(metric = 'page_actions_post_reactions_total', value, 0))                                    AS post_reactions,
        SUM(IF(metric = 'page_views_total' AND breakdown IS NULL, value, 0))                               AS page_views,
        SUM(IF(metric = 'page_total_actions' AND breakdown IS NULL, value, 0))                             AS page_actions,
        SUM(IF(metric = 'page_video_views' AND breakdown IS NULL, value, 0))                               AS video_views,
        -- Facebook reports video view time in milliseconds.
        SUM(IF(metric = 'page_video_view_time' AND breakdown IS NULL, value, 0)) / 1000                    AS video_view_time_seconds,
        MAX(IF(metric = 'page_posts_impressions' AND breakdown IS NULL, value, NULL))                      AS post_impressions_legacy,
        MAX(IF(metric = 'page_posts_impressions_unique' AND breakdown IS NULL, value, NULL))               AS post_reach_legacy
    FROM {{staging.facebook_pages.page_daily_insights}}
    GROUP BY 1, 2
)

SELECT
    p.date_day,
    p.page_id,
    pg.page_name,
    CAST(p.followers AS INT64)                                                       AS followers,
    CAST(p.followers - LAG(p.followers) OVER (PARTITION BY p.page_id ORDER BY p.date_day) AS INT64) AS follower_change,
    CAST(p.new_likes AS INT64)                                                       AS new_likes,
    CAST(p.new_likes_paid AS INT64)                                                  AS new_likes_paid,
    CAST(p.new_likes_organic AS INT64)                                               AS new_likes_organic,
    CAST(p.views AS INT64)                                                           AS views,
    CAST(p.viewers AS INT64)                                                         AS viewers,
    CAST(p.post_engagements AS INT64)                                                AS post_engagements,
    CAST(p.post_reactions AS INT64)                                                  AS post_reactions,
    CAST(p.page_views AS INT64)                                                      AS page_views,
    CAST(p.page_actions AS INT64)                                                    AS page_actions,
    CAST(p.video_views AS INT64)                                                     AS video_views,
    p.video_view_time_seconds,
    CAST(p.post_impressions_legacy AS INT64)                                         AS post_impressions_legacy,
    CAST(p.post_reach_legacy AS INT64)                                               AS post_reach_legacy
FROM pivoted p
-- One row per Page after staging, so this cannot fan out.
LEFT JOIN {{staging.facebook_pages.page}} pg USING (page_id)
