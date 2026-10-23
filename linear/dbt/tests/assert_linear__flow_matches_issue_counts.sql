-- issue_flow counts each completion once: total completed in issue_flow equals the
-- number of issues with a completed_at. Returns zero rows when they agree.

WITH flow AS (
    SELECT SUM(issues_completed) AS completed FROM {{ ref('core_linear__issue_flow') }}
),
issues AS (
    SELECT COUNT(*) AS completed FROM {{ ref('stg_linear__issue') }} WHERE completed_at IS NOT NULL
)

SELECT flow.completed AS flow_completed, issues.completed AS issues_completed
FROM flow CROSS JOIN issues
WHERE flow.completed != issues.completed
