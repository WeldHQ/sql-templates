-- stg_asana__story
-- Thin wrapper over raw `story`. One row per story (comment or system event) on a
-- task. Used for the earliest event per task, because the task stream does not
-- carry a created_at.

SELECT
    CAST(gid AS STRING)             AS story_id,
    CAST(task_gid AS STRING)        AS task_id,
    LOWER(CAST(type AS STRING))     AS story_type,
    CAST(created_by_gid AS STRING)  AS created_by_id,
    CAST(created_at AS TIMESTAMP)   AS created_at
FROM {{ source('asana', 'story') }}
WHERE gid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(gid AS STRING) ORDER BY _weld_synced DESC) = 1
