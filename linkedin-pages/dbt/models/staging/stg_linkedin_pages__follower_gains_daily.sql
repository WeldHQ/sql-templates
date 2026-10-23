-- stg_linkedin_pages__follower_gains_daily
-- Thin wrapper over raw `follower_statistics_time_bound`, the daily new followers
-- of each LinkedIn Page. Casts, renames, keeps the latest row per day. No other
-- logic.
--
-- Grain: organization x day. LinkedIn day buckets start at midnight UTC and the
-- API stops two days before today. Paid gains are followers won through a
-- sponsored post or ad.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(organization_id AS STRING)                                        AS organization_id,
        CAST(organization_name AS STRING)                                      AS organization_name,
        DATE(TIMESTAMP_MILLIS(CAST(start_date AS INT64)))                      AS date_day,
        CAST(COALESCE(organic_follower_gain, 0) AS INT64)                      AS organic_follower_gain,
        CAST(COALESCE(paid_follower_gain, 0) AS INT64)                         AS paid_follower_gain,
        ROW_NUMBER() OVER (
            PARTITION BY organization_id, CAST(start_date AS INT64) ORDER BY _weld_synced DESC
        )                                                                      AS row_rank
    FROM {{ source('linkedin_pages', 'follower_statistics_time_bound') }}
    WHERE start_date IS NOT NULL
)
WHERE row_rank = 1
