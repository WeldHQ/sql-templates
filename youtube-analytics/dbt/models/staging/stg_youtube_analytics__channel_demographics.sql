-- stg_youtube_analytics__channel_demographics
-- Thin wrapper over raw `channel_demographics_a1`, YouTube's "Viewer demographics"
-- bulk report. Casts and renames. No other logic.
--
-- Grain: date x channel x video x live/on-demand x subscribed status x country x
-- age group x gender.
--
-- views_percentage is a share, not a count: the percentage of the views in its
-- slice (date, channel, video, live/on-demand, subscribed status, country) that
-- came from this age group and gender. It covers signed-in viewers only and is
-- delivered on a 0 to 100 scale, so it is divided by 100 here. Never sum it
-- across slices; core weights it by the slice's views.

SELECT
    CAST(date AS DATE)                             AS date_day,
    CAST(channel_id AS STRING)                     AS channel_id,
    NULLIF(CAST(video_id AS STRING), '')           AS video_id,
    CAST(live_or_on_demand AS STRING)              AS live_or_on_demand,
    CAST(subscribed_status AS STRING)              AS subscribed_status,
    NULLIF(CAST(country_code AS STRING), '')       AS country_code,
    CAST(age_group AS STRING)                      AS age_group,
    CAST(gender AS STRING)                         AS gender,
    CAST(views_percentage AS FLOAT64) / 100        AS share_of_slice_views
FROM {{ source('youtube_analytics', 'channel_demographics_a1') }}
