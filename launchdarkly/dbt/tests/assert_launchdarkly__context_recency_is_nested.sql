-- Recent-activity windows are nested: 1 day <= 7 days <= 30 days <= total.
-- A violation means last_seen was parsed wrongly (for example as a string compare)
-- in staging.

SELECT *
FROM {{ ref('core_launchdarkly__context_activity') }}
WHERE contexts_seen_last_1_day  > contexts_seen_last_7_days
   OR contexts_seen_last_7_days > contexts_seen_last_30_days
   OR contexts_seen_last_30_days > contexts_total
