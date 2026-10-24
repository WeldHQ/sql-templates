-- stg_linear__issue
-- Thin wrapper over raw `issues`. One row per issue, latest version, trashed
-- issues removed. Archived issues are kept: Linear auto-archives completed work,
-- and dropping it would empty every throughput report.
--
-- Linear's API returns timestamps as ISO 8601 strings; they are cast here.
-- Priority is Linear's integer: 0 no priority, 1 urgent, 2 high, 3 medium, 4 low.
-- state_type is the workflow category: triage, backlog, unstarted, started,
-- completed or canceled. State names are team-specific; the type is not.

SELECT
    CAST(id AS STRING)                          AS issue_id,
    CAST(identifier AS STRING)                  AS identifier,
    CAST(title AS STRING)                       AS title,
    CAST(team_id AS STRING)                     AS team_id,
    CAST(team_key AS STRING)                    AS team_key,
    CAST(team_name AS STRING)                   AS team_name,
    CAST(state_id AS STRING)                    AS state_id,
    CAST(state_name AS STRING)                  AS state_name,
    LOWER(CAST(state_type AS STRING))           AS state_type,
    CAST(priority AS INT64)                     AS priority,
    CAST(priority_label AS STRING)              AS priority_label,
    CAST(estimate AS FLOAT64)                   AS estimate,
    CAST(assignee_id AS STRING)                 AS assignee_id,
    CAST(assignee_name AS STRING)               AS assignee_name,
    CAST(creator_id AS STRING)                  AS creator_id,
    CAST(creator_name AS STRING)                AS creator_name,
    CAST(parent_id AS STRING)                   AS parent_issue_id,
    CAST(project_id AS STRING)                  AS project_id,
    CAST(project_name AS STRING)                AS project_name,
    CAST(project_milestone_name AS STRING)      AS project_milestone_name,
    CAST(cycle_id AS STRING)                    AS cycle_id,
    CAST(cycle_name AS STRING)                  AS cycle_name,
    CAST(cycle_number AS INT64)                 AS cycle_number,
    SAFE_CAST(CAST(due_date AS STRING) AS DATE) AS due_date,
    SAFE_CAST(created_at AS TIMESTAMP)          AS created_at,
    SAFE_CAST(updated_at AS TIMESTAMP)          AS updated_at,
    SAFE_CAST(started_at AS TIMESTAMP)          AS started_at,
    SAFE_CAST(completed_at AS TIMESTAMP)        AS completed_at,
    SAFE_CAST(canceled_at AS TIMESTAMP)         AS canceled_at,
    SAFE_CAST(archived_at AS TIMESTAMP)         AS archived_at,
    SAFE_CAST(started_triage_at AS TIMESTAMP)   AS started_triage_at,
    SAFE_CAST(triaged_at AS TIMESTAMP)          AS triaged_at,
    SAFE_CAST(added_to_cycle_at AS TIMESTAMP)   AS added_to_cycle_at,
    SAFE_CAST(sla_breaches_at AS TIMESTAMP)     AS sla_breaches_at,
    CAST(url AS STRING)                         AS url
FROM {{ source('linear', 'issues') }}
WHERE id IS NOT NULL
  AND COALESCE(trashed, FALSE) = FALSE
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(id AS STRING)
    ORDER BY SAFE_CAST(updated_at AS TIMESTAMP) DESC, _weld_synced DESC
) = 1
