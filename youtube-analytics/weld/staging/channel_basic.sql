-- staging.youtube_analytics.channel_basic
-- Thin wrapper over raw `channel_basic_a3`, YouTube's "User activity" bulk report.
-- Casts and renames. No other logic.
--
-- Grain: date x channel x video x live/on-demand x subscribed status x country.
-- Rows with an empty video_id are channel-level activity that happened off a
-- watch page, mostly subscriptions from the channel page; they are kept and
-- video_id is set to NULL.
--
-- The connector upserts on every dimension column, so a report YouTube
-- regenerates replaces the earlier rows instead of duplicating them.

SELECT
    CAST(date AS DATE)                             AS date_day,
    CAST(channel_id AS STRING)                     AS channel_id,
    NULLIF(CAST(video_id AS STRING), '')           AS video_id,
    CAST(live_or_on_demand AS STRING)              AS live_or_on_demand,
    CAST(subscribed_status AS STRING)              AS subscribed_status,
    NULLIF(CAST(country_code AS STRING), '')       AS country_code,

    CAST(COALESCE(views, 0) AS INT64)              AS views,
    CAST(COALESCE(engaged_views, 0) AS INT64)      AS engaged_views,
    CAST(COALESCE(red_views, 0) AS INT64)          AS premium_views,
    CAST(COALESCE(watch_time_minutes, 0) AS FLOAT64)     AS watch_time_minutes,
    CAST(COALESCE(red_watch_time_minutes, 0) AS FLOAT64) AS premium_watch_time_minutes,
    -- Per-row averages. Core weights them by views; never sum them.
    CAST(average_view_duration_percentage AS FLOAT64)    AS average_view_duration_percentage,

    CAST(COALESCE(likes, 0) AS INT64)              AS likes,
    CAST(COALESCE(dislikes, 0) AS INT64)           AS dislikes,
    CAST(COALESCE(comments, 0) AS INT64)           AS comments,
    CAST(COALESCE(shares, 0) AS INT64)             AS shares,
    CAST(COALESCE(videos_added_to_playlists, 0) AS INT64)     AS added_to_playlists,
    CAST(COALESCE(videos_removed_from_playlists, 0) AS INT64) AS removed_from_playlists,
    CAST(COALESCE(subscribers_gained, 0) AS INT64) AS subscribers_gained,
    CAST(COALESCE(subscribers_lost, 0) AS INT64)   AS subscribers_lost
FROM {{raw.youtube_analytics.channel_basic_a3}}
