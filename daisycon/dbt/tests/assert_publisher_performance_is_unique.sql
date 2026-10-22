-- One row per advertiser and publisher. A duplicate means the statistics stream
-- returned the same publisher twice (for example in two currencies) and the
-- connector's key no longer holds.
-- Returns zero rows when the grain holds.

SELECT advertiser_id, publisher_id, COUNT(*) AS row_count
FROM {{ ref('core_daisycon__publisher_performance') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
