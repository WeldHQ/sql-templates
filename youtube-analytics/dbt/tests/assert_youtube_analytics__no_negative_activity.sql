-- Views, watch time and subscriber counts are never negative in YouTube's
-- reports. Net subscribers can be, so it is not checked.

SELECT *
FROM {{ ref('core_youtube_analytics__video_performance_daily') }}
WHERE views < 0 OR watch_time_minutes < 0 OR subscribers_gained < 0 OR subscribers_lost < 0
