-- stg_linkedin_pages__total_follower_count
-- Thin wrapper over raw `total_follower_count`. Casts, renames, keeps the latest
-- row per organization. No other logic.
--
-- Grain: one row per organization. A snapshot of the follower count at the last
-- sync, not a history: the connector replaces the table on every sync.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(organization_id AS STRING)                                        AS organization_id,
        CAST(organization_name AS STRING)                                      AS organization_name,
        CAST(total_follower_count AS INT64)                                    AS follower_count,
        CAST(_weld_synced AS TIMESTAMP)                                        AS synced_at,
        ROW_NUMBER() OVER (PARTITION BY organization_id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('linkedin_pages', 'total_follower_count') }}
)
WHERE row_rank = 1
