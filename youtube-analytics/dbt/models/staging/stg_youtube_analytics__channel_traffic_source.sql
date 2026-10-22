-- stg_youtube_analytics__channel_traffic_source
-- Thin wrapper over raw `channel_traffic_source_a3`, YouTube's "Traffic sources"
-- bulk report. Casts, renames, labels the numeric source type. No other logic.
--
-- Grain: date x channel x video x live/on-demand x subscribed status x country x
-- traffic source type x traffic source detail.
-- Labels follow YouTube's Reporting API dimension reference; an unknown code is
-- kept as its number so new sources stay visible.

SELECT
    CAST(date AS DATE)                             AS date_day,
    CAST(channel_id AS STRING)                     AS channel_id,
    NULLIF(CAST(video_id AS STRING), '')           AS video_id,
    NULLIF(CAST(country_code AS STRING), '')       AS country_code,
    CAST(traffic_source_type AS STRING)            AS traffic_source_type,
    CASE CAST(traffic_source_type AS STRING)
        WHEN '0'  THEN 'Direct or unknown'
        WHEN '1'  THEN 'YouTube advertising'
        WHEN '3'  THEN 'Browse features'
        WHEN '4'  THEN 'YouTube channels'
        WHEN '5'  THEN 'YouTube search'
        WHEN '7'  THEN 'Suggested videos'
        WHEN '8'  THEN 'Other YouTube features'
        WHEN '9'  THEN 'External'
        WHEN '11' THEN 'Video cards and annotations'
        WHEN '14' THEN 'Playlists'
        WHEN '17' THEN 'Notifications'
        WHEN '18' THEN 'Playlist pages'
        WHEN '19' THEN 'Programming from claimed content'
        WHEN '20' THEN 'Interactive video endscreen'
        WHEN '23' THEN 'Stories'
        WHEN '24' THEN 'Shorts'
        WHEN '25' THEN 'Product pages'
        WHEN '26' THEN 'Hashtag pages'
        WHEN '27' THEN 'Sound pages'
        WHEN '28' THEN 'Live redirect'
        WHEN '29' THEN 'Podcasts'
        WHEN '30' THEN 'Remixed video'
        WHEN '31' THEN 'Vertical live feed'
        WHEN '32' THEN 'Related video'
        ELSE CONCAT('Type ', CAST(traffic_source_type AS STRING))
    END                                            AS traffic_source,
    NULLIF(CAST(traffic_source_detail AS STRING), '') AS traffic_source_detail,
    CAST(COALESCE(views, 0) AS INT64)              AS views,
    CAST(COALESCE(engaged_views, 0) AS INT64)      AS engaged_views,
    CAST(COALESCE(watch_time_minutes, 0) AS FLOAT64) AS watch_time_minutes
FROM {{ source('youtube_analytics', 'channel_traffic_source_a3') }}
