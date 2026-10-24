-- stg_linkedin_pages__share_statistics_daily
-- Thin wrapper over raw `share_statistics_time_bound`, the daily organic share
-- statistics of each LinkedIn Page. Casts, renames, keeps the latest row per day.
-- No other logic.
--
-- Grain: organization x day. LinkedIn day buckets start at midnight UTC.
-- Organic only: LinkedIn excludes sponsored activity from this endpoint, so a
-- like on a boosted post can show up here as a negative like when it is removed.
-- `engagement` is LinkedIn's own rate (clicks, likes, comments and shares over
-- impressions), not a count. Never sum it.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(organization_id AS STRING)                                        AS organization_id,
        CAST(organization_name AS STRING)                                      AS organization_name,
        DATE(TIMESTAMP_MILLIS(CAST(start_date AS INT64)))                      AS date_day,
        CAST(COALESCE(impression_count, 0) AS INT64)                           AS impressions,
        -- Unique members who saw a post that day. Not additive across days.
        CAST(unique_impressions_count AS INT64)                                AS unique_impressions,
        CAST(COALESCE(click_count, 0) AS INT64)                                AS clicks,
        CAST(COALESCE(like_count, 0) AS INT64)                                 AS likes,
        CAST(COALESCE(comment_count, 0) AS INT64)                              AS comments,
        CAST(COALESCE(share_count, 0) AS INT64)                                AS shares,
        CAST(engagement AS FLOAT64)                                            AS engagement_rate,
        ROW_NUMBER() OVER (
            PARTITION BY organization_id, CAST(start_date AS INT64) ORDER BY _weld_synced DESC
        )                                                                      AS row_rank
    FROM {{ source('linkedin_pages', 'share_statistics_time_bound') }}
    WHERE start_date IS NOT NULL
)
WHERE row_rank = 1
