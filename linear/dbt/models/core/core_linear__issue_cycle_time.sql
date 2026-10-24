-- core_linear__issue_cycle_time
-- Lead time, cycle time and triage time for every completed issue.
-- Recreates the cycle time and lead time charts in Linear Insights.
-- Grain: completed issue.
--
--   lead_time_days   created   -> completed
--   cycle_time_days  started   -> completed (NULL if the issue skipped "started")
--   triage_time_days entered triage -> left triage (NULL if never in triage)
--
-- Times are in fractional days. Report medians or percentiles rather than means:
-- one issue that sat in the backlog for a year will dominate an average.

SELECT
    i.issue_id,
    i.identifier,
    i.title,
    i.team_id,
    i.team_name,
    i.project_id,
    i.project_name,
    i.cycle_id,
    i.cycle_number,
    i.assignee_id,
    i.assignee_name,
    i.priority,
    i.priority_label,
    i.estimate,
    i.parent_issue_id IS NOT NULL                                             AS is_sub_issue,
    i.created_at,
    i.started_at,
    i.completed_at,
    DATE(i.completed_at)                                                      AS completed_date,
    ROUND(TIMESTAMP_DIFF(i.completed_at, i.created_at, SECOND) / 86400, 2)    AS lead_time_days,
    ROUND(TIMESTAMP_DIFF(i.completed_at, i.started_at, SECOND) / 86400, 2)    AS cycle_time_days,
    ROUND(TIMESTAMP_DIFF(i.triaged_at, i.started_triage_at, SECOND) / 86400, 2) AS triage_time_days,
    i.due_date,
    i.due_date IS NOT NULL AND DATE(i.completed_at) > i.due_date              AS completed_after_due_date
FROM {{ ref('stg_linear__issue') }} i
WHERE i.completed_at IS NOT NULL
  AND i.state_type = 'completed'
