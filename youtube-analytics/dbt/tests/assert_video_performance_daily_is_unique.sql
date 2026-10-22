-- One row per day, channel and video. A duplicate means the reach join fanned out.

SELECT date_day, channel_id, video_id, COUNT(*) AS row_count
FROM {{ ref('core_youtube_analytics__video_performance_daily') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
