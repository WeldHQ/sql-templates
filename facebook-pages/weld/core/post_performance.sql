-- core.facebook_pages.post_performance
-- The Posts list of Page Insights / Meta Business Suite: every post with its
-- lifetime views, viewers, reactions, comments, shares, clicks and engagement
-- rate.
--
-- Grain: one row per post. Metrics are lifetime totals as of `metrics_as_of`,
-- the last sync; they keep growing while a post is live, so this is a snapshot,
-- not a time series. Never sum a post's figures across snapshots.
-- Depends on: staging.facebook_pages.post, .post_lifetime_insights, .page
--
-- ENGAGEMENT RATE = (reactions + comments + shares + clicks) / viewers.
-- Reactions, comments and shares come from post_activity_by_action_type, clicks
-- from post_clicks. viewers (post_total_media_view_unique) is Meta's replacement
-- for reach since June 2026; reach_legacy keeps the old reach figure where it
-- was synced before the cutover. To roll up a set of posts, divide the summed
-- engagements by the summed viewers; averaging engagement_rate over posts
-- weights a small post like a large one.

WITH metrics AS (
    SELECT
        post_id,
        MAX(synced_at)                                                                          AS metrics_as_of,
        MAX(IF(metric = 'post_media_view_all' AND breakdown IS NULL, value, NULL))              AS views,
        MAX(IF(metric = 'post_media_view_followers' AND breakdown IS NULL, value, NULL))        AS views_from_followers,
        MAX(IF(metric = 'post_media_view_non_followers' AND breakdown IS NULL, value, NULL))    AS views_from_non_followers,
        MAX(IF(metric = 'post_media_view_ads' AND breakdown IS NULL, value, NULL))              AS views_from_ads,
        MAX(IF(metric = 'post_total_media_view_unique' AND breakdown IS NULL, value, NULL))     AS viewers,
        MAX(IF(metric = 'post_impressions_unique' AND breakdown IS NULL, value, NULL))          AS reach_legacy,
        SUM(IF(metric = 'post_activity_by_action_type' AND breakdown = 'like', value, 0))       AS reactions,
        SUM(IF(metric = 'post_activity_by_action_type' AND breakdown = 'comment', value, 0))    AS comments,
        SUM(IF(metric = 'post_activity_by_action_type' AND breakdown = 'share', value, 0))      AS shares,
        SUM(IF(metric = 'post_clicks' AND breakdown IS NULL, value, 0))                         AS clicks
    FROM {{staging.facebook_pages.post_lifetime_insights}}
    GROUP BY 1
)

SELECT
    p.post_id,
    p.page_id,
    pg.page_name,
    p.created_at,
    DATE(p.created_at, 'America/Los_Angeles')                                 AS created_date,
    p.status_type,
    p.message,
    p.permalink_url,
    m.metrics_as_of,
    CAST(m.views AS INT64)                                                    AS views,
    CAST(m.views_from_followers AS INT64)                                     AS views_from_followers,
    CAST(m.views_from_non_followers AS INT64)                                 AS views_from_non_followers,
    CAST(m.views_from_ads AS INT64)                                           AS views_from_ads,
    CAST(m.viewers AS INT64)                                                  AS viewers,
    CAST(m.reach_legacy AS INT64)                                             AS reach_legacy,
    CAST(m.reactions AS INT64)                                                AS reactions,
    CAST(m.comments AS INT64)                                                 AS comments,
    CAST(m.shares AS INT64)                                                   AS shares,
    CAST(m.clicks AS INT64)                                                   AS clicks,
    CAST(m.reactions + m.comments + m.shares + m.clicks AS INT64)             AS engagements,
    SAFE_DIVIDE(m.reactions + m.comments + m.shares + m.clicks, m.viewers)    AS engagement_rate
FROM {{staging.facebook_pages.post}} p
-- metrics is one row per post and page is one row per Page, so neither join fans out.
LEFT JOIN metrics m USING (post_id)
LEFT JOIN {{staging.facebook_pages.page}} pg ON pg.page_id = p.page_id
