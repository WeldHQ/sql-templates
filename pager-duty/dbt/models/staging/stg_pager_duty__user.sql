-- stg_pager_duty__user
-- Thin wrapper over raw `user`. Casts, renames, keeps the latest row per user.
-- Grain: one row per PagerDuty user.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)          AS user_id,
        CAST(name AS STRING)        AS user_name,
        CAST(time_zone AS STRING)   AS time_zone,
        CAST(role AS STRING)        AS role,
        CAST(job_title AS STRING)   AS job_title,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('pager_duty', 'user') }}
)
WHERE row_rank = 1
