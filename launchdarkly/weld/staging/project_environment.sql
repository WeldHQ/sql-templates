-- staging.launchdarkly.project_environment
-- Thin wrapper over raw `project_environment`: the environments in each project.
-- Casts, renames, keeps the latest row per environment.
--
-- Grain: one row per environment (id). Environment keys such as `production` repeat
-- across projects, so always join on project_id and key together.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                          AS environment_id,
        CAST(project_id AS STRING)                  AS project_id,
        CAST(key AS STRING)                         AS environment_key,
        CAST(name AS STRING)                        AS environment_name,
        COALESCE(CAST(critical AS BOOL), FALSE)     AS is_critical,
        COALESCE(CAST(approval_settings_required AS BOOL), FALSE) AS requires_approval,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.launchdarkly.project_environment}}
)
WHERE row_rank = 1
