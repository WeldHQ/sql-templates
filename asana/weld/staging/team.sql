-- staging.asana.team
-- Thin wrapper over raw `team`. One row per team.

SELECT
    CAST(gid AS STRING)   AS team_id,
    CAST(name AS STRING)  AS team_name
FROM {{raw.asana.team}}
WHERE gid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(gid AS STRING) ORDER BY _weld_synced DESC) = 1
