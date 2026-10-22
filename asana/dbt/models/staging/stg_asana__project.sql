-- stg_asana__project
-- Thin wrapper over raw `project`. One row per project.

SELECT
    CAST(gid AS STRING)                         AS project_id,
    CAST(workspace_gid AS STRING)               AS workspace_id,
    CAST(team_gid AS STRING)                    AS team_id,
    CAST(owner_gid AS STRING)                   AS owner_id,
    CAST(name AS STRING)                        AS project_name,
    COALESCE(archived, FALSE)                   AS is_archived,
    COALESCE(public, FALSE)                     AS is_public,
    -- Asana's status colour: green (on track), yellow (at risk), red (off track),
    -- blue (on hold), complete. NULL when no status update has been posted.
    LOWER(CAST(current_status_color AS STRING)) AS current_status_color,
    CAST(current_status_gid AS STRING)          AS current_status_id,
    DATE(CAST(due_date AS TIMESTAMP))           AS due_date,
    CAST(created_at AS TIMESTAMP)               AS created_at,
    CAST(modified_at AS TIMESTAMP)              AS modified_at
FROM {{ source('asana', 'project') }}
WHERE gid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(gid AS STRING) ORDER BY _weld_synced DESC) = 1
