-- core_mixpanel_source__funnel_conversion_daily
-- Your saved Mixpanel funnels, step by step per entry day: how many users reached each
-- step, the conversion from the previous step and from the start, and the time it took.
--
-- Grain: one row per funnel x day (users' entry day) x step.
-- Depends on: staging.mixpanel_source.funnel_step
--
-- These are Mixpanel's own funnel numbers, computed with each funnel's saved conversion
-- window and identity rules, so they match the Funnels report for the same days.
-- `drop_off` is users who reached the previous step and not this one.
--
-- To report a funnel over a week or a month, sum `users` per step and divide step by
-- step one; averaging the daily conversion rates weights a quiet day like a busy one.
-- Recent days keep changing until the conversion window has passed.

SELECT
    funnel_id,
    funnel_name,
    date,
    step_number,
    step_label,
    step_event,
    users,
    FIRST_VALUE(users) OVER w                               AS users_entered,
    LAG(users) OVER w - users                               AS drop_off,
    step_conversion,
    overall_conversion,
    avg_seconds_from_previous_step,
    avg_seconds_from_start
FROM {{ ref('stg_mixpanel_source__funnel_step') }}
WINDOW w AS (PARTITION BY funnel_id, date ORDER BY step_number)
