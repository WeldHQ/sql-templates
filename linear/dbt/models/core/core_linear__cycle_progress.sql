-- core_linear__cycle_progress
-- Scope and completion per cycle: the numbers behind Linear's cycle graph.
-- Grain: team x cycle.
--
-- Built from each issue's CURRENT cycle. Issues that were in a cycle and rolled
-- over to the next one count in the cycle they are in now, so a finished cycle's
-- scope here is what remained in it, not what was planned at the start. Linear's
-- own cycle graph uses its history and will show a larger starting scope.
-- Cycle start and end dates are not synced; the first and last activity dates
-- below are a stand-in.

SELECT
    i.team_id,
    ANY_VALUE(i.team_name)                                            AS team_name,
    i.cycle_id,
    ANY_VALUE(i.cycle_number)                                         AS cycle_number,
    ANY_VALUE(i.cycle_name)                                           AS cycle_name,
    COUNT(*)                                                          AS scope_issues,
    COUNTIF(i.state_type = 'completed')                               AS completed_issues,
    COUNTIF(i.state_type = 'canceled')                                AS canceled_issues,
    COUNTIF(i.state_type = 'started')                                 AS in_progress_issues,
    COUNTIF(i.state_type IN ('triage', 'backlog', 'unstarted'))       AS not_started_issues,
    SUM(COALESCE(i.estimate, 0))                                      AS scope_points,
    SUM(IF(i.state_type = 'completed', COALESCE(i.estimate, 0), 0))   AS completed_points,
    SAFE_DIVIDE(COUNTIF(i.state_type = 'completed'),
                COUNTIF(i.state_type != 'canceled'))                  AS pct_issues_completed,
    MIN(DATE(i.added_to_cycle_at))                                    AS first_added_date,
    MAX(DATE(i.completed_at))                                         AS last_completed_date
FROM {{ ref('stg_linear__issue') }} i
WHERE i.cycle_id IS NOT NULL
GROUP BY i.team_id, i.cycle_id
