-- staging.sona.pay_lines
-- Thin wrapper over raw `pay_lines`: the time lines Sona sends to payroll, one per
-- block of paid time. Casts, renames, de-duplicates, drops rows Sona has deleted.
--
-- Grain: one row per pay line (id).
--
-- Deleted pay lines are marked with `_weld_deleted_at` and filtered out here; if
-- soft deletes are off for this stream, remove that line. Rates are left out on
-- purpose: Sona returns hourly and annual rates in the same column, so a cost
-- computed from them is only right for some lines.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                  AS pay_line_id,
        CAST(start_datetime AS TIMESTAMP)   AS starts_at,
        CAST(end_datetime AS TIMESTAMP)     AS ends_at,
        CAST(duration_in_minutes AS INT64)  AS duration_minutes,
        CAST(user_id AS STRING)             AS user_id,
        CAST(shift_id AS STRING)            AS shift_id,
        CAST(shift_type_name AS STRING)     AS shift_type_name,
        CAST(entry_type AS STRING)          AS entry_type,
        CAST(pay_type AS STRING)            AS pay_type,
        CAST(variant AS STRING)             AS variant,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sona.pay_lines}}
    WHERE _weld_deleted_at IS NULL
)
WHERE row_rank = 1
