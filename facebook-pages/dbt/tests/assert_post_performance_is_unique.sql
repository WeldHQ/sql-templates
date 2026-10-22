-- One row per post. A duplicate means the metrics or Page join fanned out.

SELECT post_id, COUNT(*) AS row_count
FROM {{ ref('core_facebook_pages__post_performance') }}
GROUP BY 1
HAVING COUNT(*) > 1
