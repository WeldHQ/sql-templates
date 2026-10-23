-- One row per video. A duplicate means the profile join fanned out.

SELECT video_id, COUNT(*) AS row_count
FROM {{ ref('core_tiktok_organic__video_performance') }}
GROUP BY 1
HAVING COUNT(*) > 1
