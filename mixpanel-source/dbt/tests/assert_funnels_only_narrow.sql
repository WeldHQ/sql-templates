-- A funnel can only lose users from one step to the next.
--
-- If a later step shows more users than the one before it, the JSON unpacking in
-- stg_mixpanel_source__funnel_step has put steps in the wrong order, or two synced copies
-- of the same funnel day were mixed.

SELECT funnel_id, date, step_number, users, drop_off
FROM {{ ref('core_mixpanel_source__funnel_conversion_daily') }}
WHERE drop_off < 0
