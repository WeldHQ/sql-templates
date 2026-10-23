-- Within a channel and day, the age and gender shares must add up to 1. A gap
-- means the demographic slices joined to the wrong activity rows or fanned out.

SELECT date_day, channel_id, SUM(share_of_views) AS share_total
FROM {{ ref('core_youtube_analytics__viewer_demographics_daily') }}
GROUP BY 1, 2
HAVING SUM(estimated_views) > 0 AND ABS(SUM(share_of_views) - 1) > 0.0001
