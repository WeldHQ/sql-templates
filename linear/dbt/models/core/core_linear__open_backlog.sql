-- core_linear__open_backlog
-- Everything still open, by team, workflow state, priority and assignee, with
-- age and overdue counts. A snapshot as of the last sync.
-- Grain: team x state x priority x assignee.
--
-- Open means state_type in triage, backlog, unstarted or started. Age is days
-- since the issue was created, in UTC. Average age is carried as a sum and a
-- count so it can be re-aggregated.

SELECT
    i.team_id,
    i.team_name,
    i.state_name,
    i.state_type,
    i.priority,
    i.priority_label,
    i.assignee_id,
    i.assignee_name,
    COUNT(*)                                                          AS open_issues,
    COUNTIF(i.estimate IS NULL)                                       AS unestimated_issues,
    SUM(COALESCE(i.estimate, 0))                                      AS open_points,
    COUNTIF(i.due_date < CURRENT_DATE())                              AS overdue_issues,
    COUNTIF(i.sla_breaches_at < CURRENT_TIMESTAMP())                  AS sla_breached_issues,
    COUNTIF(i.cycle_id IS NOT NULL)                                   AS issues_in_a_cycle,
    SUM(DATE_DIFF(CURRENT_DATE(), DATE(i.created_at), DAY))           AS age_days_total,
    ROUND(AVG(DATE_DIFF(CURRENT_DATE(), DATE(i.created_at), DAY)), 1) AS avg_age_days,
    MAX(DATE_DIFF(CURRENT_DATE(), DATE(i.created_at), DAY))           AS oldest_age_days
FROM {{ ref('stg_linear__issue') }} i
WHERE i.state_type IN ('triage', 'backlog', 'unstarted', 'started')
  AND i.archived_at IS NULL
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
