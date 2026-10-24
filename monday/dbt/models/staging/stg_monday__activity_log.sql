-- stg_monday__activity_log
-- Thin wrapper over raw `activity_logs`. One row per activity log event.
--
-- monday sends `created_at` as a 17-digit number in units of 100 nanoseconds
-- since the Unix epoch, so it is divided by 10 to get microseconds. The event
-- payload `data` is JSON; it is parsed here and read in core.
--
-- monday only keeps activity log history for a limited period that depends on
-- the plan, so this table starts when your plan's retention window started, not
-- when the board was created.

SELECT
    CAST(id AS STRING)                                  AS activity_log_id,
    CAST(board_id AS STRING)                            AS board_id,
    CAST(user_id AS STRING)                             AS user_id,
    LOWER(CAST(event AS STRING))                        AS event,
    CAST(entity AS STRING)                              AS entity,
    TIMESTAMP_MICROS(CAST(DIV(CAST(created_at AS INT64), 10) AS INT64)) AS created_at,
    SAFE.PARSE_JSON(CAST(data AS STRING))               AS data_json
FROM {{ source('monday', 'activity_logs') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(id AS STRING) ORDER BY _weld_synced DESC) = 1
