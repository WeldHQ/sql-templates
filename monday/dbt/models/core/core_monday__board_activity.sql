-- core_monday__board_activity
-- Daily activity per board, user and event type, from the monday activity log.
-- Grain: day (UTC) x board x user x event.
--
-- `event` is monday's own event name: create_pulse (item created),
-- update_column_value, move_pulse_into_group, update_name, delete_pulse and so on.
-- `items_touched` counts distinct items (monday calls them pulses) the events
-- refer to; it is distinct within a row only, so do not sum it across rows.
--
-- Only covers the activity log retention window of your monday plan.

WITH logs AS (
    SELECT
        DATE(created_at)                                  AS activity_date,
        board_id,
        user_id,
        event,
        JSON_VALUE(data_json, '$.pulse_id')               AS item_id
    FROM {{ ref('stg_monday__activity_log') }}
)

SELECT
    l.activity_date,
    l.board_id,
    b.board_name,
    l.user_id,
    u.user_name,
    l.event,
    COUNT(*)                       AS events,
    COUNT(DISTINCT l.item_id)      AS items_touched
FROM logs l
LEFT JOIN {{ ref('stg_monday__board') }} b ON b.board_id = l.board_id
LEFT JOIN {{ ref('stg_monday__user') }} u ON u.user_id = l.user_id
GROUP BY 1, 2, 3, 4, 5, 6
