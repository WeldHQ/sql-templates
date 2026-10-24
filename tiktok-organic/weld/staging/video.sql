-- staging.tiktok_organic.video
-- Thin wrapper over raw `video`, one row per published video with TikTok's
-- lifetime insights. Casts, renames, keeps the latest row per video. No other
-- logic.
--
-- Grain: one row per video. Metrics are lifetime totals as of the last sync; the
-- connector rereads every video each time and replaces the table, so this is a
-- snapshot. Durations and watch times are in seconds.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(item_id AS STRING)                              AS video_id,
        CAST(business_id AS STRING)                          AS business_id,
        -- create_time is Unix seconds, UTC.
        TIMESTAMP_SECONDS(SAFE_CAST(create_time AS INT64))   AS created_at,
        CAST(caption AS STRING)                              AS caption,
        CAST(share_url AS STRING)                            AS share_url,
        CAST(thumbnail_url AS STRING)                        AS thumbnail_url,
        CAST(video_duration AS FLOAT64)                      AS duration_seconds,
        CAST(COALESCE(video_views, 0) AS INT64)              AS video_views,
        CAST(reach AS INT64)                                 AS reach,
        CAST(COALESCE(likes, 0) AS INT64)                    AS likes,
        CAST(COALESCE(comments, 0) AS INT64)                 AS comments,
        CAST(COALESCE(shares, 0) AS INT64)                   AS shares,
        CAST(full_video_watched_rate AS FLOAT64)             AS full_video_watched_rate,
        CAST(total_time_watched AS FLOAT64)                  AS total_time_watched_seconds,
        CAST(average_time_watched AS FLOAT64)                AS average_time_watched_seconds,
        CAST(_weld_synced AS TIMESTAMP)                      AS synced_at,
        ROW_NUMBER() OVER (PARTITION BY item_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.tiktok_organic.video}}
    WHERE item_id IS NOT NULL
)
WHERE row_rank = 1
