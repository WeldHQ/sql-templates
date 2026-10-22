-- core_linear__issue_flow
-- Issues created, started, completed and canceled per day, team and assignee.
-- The created-vs-completed chart from Linear Insights, as a table.
-- Grain: day (UTC) x team x assignee.
--
-- Each issue contributes to up to four days: the day it was created, started,
-- completed and canceled. Team and assignee are the issue's CURRENT values: an
-- issue moved between teams counts all its events under the team it is in now.
-- Linear does not expose state history through this connector.

WITH events AS (
    SELECT team_id, team_name, assignee_id, assignee_name, DATE(created_at) AS day,
           1 AS created, 0 AS started, 0 AS completed, 0 AS canceled, 0.0 AS points_completed
    FROM {{ ref('stg_linear__issue') }} WHERE created_at IS NOT NULL
    UNION ALL
    SELECT team_id, team_name, assignee_id, assignee_name, DATE(started_at),
           0, 1, 0, 0, 0.0
    FROM {{ ref('stg_linear__issue') }} WHERE started_at IS NOT NULL
    UNION ALL
    SELECT team_id, team_name, assignee_id, assignee_name, DATE(completed_at),
           0, 0, 1, 0, COALESCE(estimate, 0)
    FROM {{ ref('stg_linear__issue') }} WHERE completed_at IS NOT NULL
    UNION ALL
    SELECT team_id, team_name, assignee_id, assignee_name, DATE(canceled_at),
           0, 0, 0, 1, 0.0
    FROM {{ ref('stg_linear__issue') }} WHERE canceled_at IS NOT NULL
)

SELECT
    day,
    team_id,
    ANY_VALUE(team_name)        AS team_name,
    assignee_id,
    ANY_VALUE(assignee_name)    AS assignee_name,
    SUM(created)                AS issues_created,
    SUM(started)                AS issues_started,
    SUM(completed)              AS issues_completed,
    SUM(canceled)               AS issues_canceled,
    SUM(points_completed)       AS points_completed
FROM events
GROUP BY day, team_id, assignee_id
