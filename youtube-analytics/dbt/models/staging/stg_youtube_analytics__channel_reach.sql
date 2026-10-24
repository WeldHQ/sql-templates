-- stg_youtube_analytics__channel_reach
-- Thin wrapper over raw `channel_reach_basic_a1`, YouTube's thumbnail impressions
-- report. Casts and renames. No other logic.
--
-- Grain: date x channel x video.
--
-- Click-through rate is kept in the unit YouTube delivers it. Core turns it into
-- estimated clicks (impressions x CTR) so it can be re-aggregated; check one video
-- against YouTube Studio to see whether your rows hold a fraction or a percentage.

SELECT
    CAST(date AS DATE)                                     AS date_day,
    CAST(channel_id AS STRING)                             AS channel_id,
    NULLIF(CAST(video_id AS STRING), '')                   AS video_id,
    CAST(COALESCE(video_thumbnail_impressions, 0) AS INT64) AS thumbnail_impressions,
    CAST(video_thumbnail_impressions_ctr AS FLOAT64)       AS thumbnail_ctr
FROM {{ source('youtube_analytics', 'channel_reach_basic_a1') }}
