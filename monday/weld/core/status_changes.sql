-- core.monday.status_changes
-- Every change to a status column, with the label before and after and how long
-- the item sat in the previous label.
-- Grain: one row per status change event (item x status column x change time).
--
-- Status label text is only available here. The item's column value stores the
-- label index, and board column settings are not synced, so the
-- activity log is the one place where "Working on it" or "Done" appears as text.
-- `is_current_label` marks the latest change per item and column, which is the
-- item's current status as long as the change happened inside the activity log
-- retention window.
--
-- `hours_in_previous_label` is NULL for the first change seen per item and
-- column: the time the item entered that label is outside the synced log.
-- monday names the status column type "color" in activity log payloads.

WITH changes AS (
    SELECT
        a.activity_log_id,
        a.board_id,
        JSON_VALUE(a.data_json, '$.pulse_id')                 AS item_id,
        JSON_VALUE(a.data_json, '$.pulse_name')               AS item_name_at_change,
        JSON_VALUE(a.data_json, '$.column_id')                AS column_id,
        JSON_VALUE(a.data_json, '$.column_title')             AS column_title,
        JSON_VALUE(a.data_json, '$.previous_value.label.text') AS from_label,
        JSON_VALUE(a.data_json, '$.value.label.text')         AS to_label,
        a.user_id,
        a.created_at                                          AS changed_at
    FROM {{staging.monday.activity_log}} a
    WHERE a.event = 'update_column_value'
      AND LOWER(JSON_VALUE(a.data_json, '$.column_type')) IN ('color', 'status')
),

sequenced AS (
    SELECT
        *,
        LAG(changed_at) OVER (PARTITION BY item_id, column_id ORDER BY changed_at, activity_log_id) AS previous_changed_at,
        ROW_NUMBER() OVER (PARTITION BY item_id, column_id ORDER BY changed_at DESC, activity_log_id DESC) AS recency
    FROM changes
)

SELECT
    s.activity_log_id,
    s.changed_at,
    DATE(s.changed_at)                       AS change_date,
    s.board_id,
    b.board_name,
    s.item_id,
    COALESCE(i.item_name, s.item_name_at_change) AS item_name,
    s.column_id,
    s.column_title,
    s.from_label,
    s.to_label,
    s.user_id,
    u.user_name,
    s.previous_changed_at,
    ROUND(TIMESTAMP_DIFF(s.changed_at, s.previous_changed_at, SECOND) / 3600, 2) AS hours_in_previous_label,
    s.recency = 1                            AS is_current_label
FROM sequenced s
LEFT JOIN {{staging.monday.board}} b ON b.board_id = s.board_id
LEFT JOIN {{staging.monday.item}} i ON i.item_id = s.item_id
LEFT JOIN {{staging.monday.user}} u ON u.user_id = s.user_id
