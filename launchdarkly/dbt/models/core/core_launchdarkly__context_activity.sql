-- core_launchdarkly__context_activity
-- How many contexts each environment has seen, and how many were active recently.
-- LaunchDarkly bills client-side usage on monthly active contexts, so the 30-day
-- column is the one to watch against your plan.
--
-- Grain: one row per project x environment x context kind (current state as of the
-- last sync).
-- Depends on: staging.launchdarkly.context, staging.launchdarkly.project_environment,
--             staging.launchdarkly.project
--
-- Recency is measured from CURRENT_DATE() using each context's last_seen. This is a
-- snapshot: last_seen moves forward on every evaluation, so the table cannot tell
-- you how many contexts were active in a past month. Schedule a daily copy of this
-- model if you want that history.

SELECT
    c.project_id,
    ANY_VALUE(p.project_key)                                            AS project_key,
    ANY_VALUE(p.project_name)                                           AS project_name,
    c.environment_key,
    ANY_VALUE(e.environment_name)                                       AS environment_name,
    ANY_VALUE(e.is_critical)                                            AS is_critical_environment,
    c.context_kind,

    COUNT(*)                                                            AS contexts_total,
    COUNTIF(DATE(c.last_seen_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY))  AS contexts_seen_last_1_day,
    COUNTIF(DATE(c.last_seen_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY))  AS contexts_seen_last_7_days,
    COUNTIF(DATE(c.last_seen_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)) AS contexts_seen_last_30_days,
    COUNTIF(DATE(c.last_seen_at) >= DATE_TRUNC(CURRENT_DATE(), MONTH))         AS contexts_seen_this_month,
    MAX(c.last_seen_at)                                                 AS latest_seen_at
FROM {{ ref('stg_launchdarkly__context') }} c
LEFT JOIN {{ ref('stg_launchdarkly__project_environment') }} e
  ON  e.project_id      = c.project_id
  AND e.environment_key = c.environment_key
LEFT JOIN {{ ref('stg_launchdarkly__project') }} p
  ON p.project_id = c.project_id
GROUP BY c.project_id, c.environment_key, c.context_kind
