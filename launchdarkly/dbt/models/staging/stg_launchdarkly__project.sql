-- stg_launchdarkly__project
-- Thin wrapper over raw `project`. Casts, renames, keeps the latest row per project.
-- Grain: one row per project.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)      AS project_id,
        CAST(key AS STRING)     AS project_key,
        CAST(name AS STRING)    AS project_name,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('launchdarkly', 'project') }}
)
WHERE row_rank = 1
