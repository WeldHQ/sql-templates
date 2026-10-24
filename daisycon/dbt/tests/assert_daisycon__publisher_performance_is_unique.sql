-- One row per advertiser and publisher. A duplicate means the statistics table
-- holds the same publisher twice (for example in two currencies).
-- Returns zero rows when the grain holds.

SELECT advertiser_id, publisher_id, COUNT(*) AS row_count
FROM {{ ref('core_daisycon__publisher_performance') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
