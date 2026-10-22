-- staging.tiktok_organic.profile_metrics
-- Thin wrapper over raw `profile_metrics`, TikTok's daily account metrics.
-- Casts, renames, keeps the latest row per account and day. No other logic.
--
-- Grain: business_id x day. Days are UTC.
-- followers is the account's follower total on that day, a running total. The
-- other columns count the day itself. TikTok reports a day as 0 until it has
-- processed it, 24 to 48 hours after the day ends; the connector re-reads the
-- last week once a day so those zeros get replaced.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(business_id AS STRING)               AS business_id,
        SAFE.PARSE_DATE('%Y-%m-%d', CAST(date AS STRING)) AS date_day,
        CAST(followers_count AS INT64)            AS followers,
        CAST(COALESCE(profile_views, 0) AS INT64) AS profile_views,
        CAST(COALESCE(video_views, 0) AS INT64)   AS video_views,
        CAST(COALESCE(likes, 0) AS INT64)         AS likes,
        CAST(COALESCE(comments, 0) AS INT64)      AS comments,
        CAST(COALESCE(shares, 0) AS INT64)        AS shares,
        ROW_NUMBER() OVER (PARTITION BY business_id, date ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.tiktok_organic.profile_metrics}}
)
WHERE row_rank = 1
