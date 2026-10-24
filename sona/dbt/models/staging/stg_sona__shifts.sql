-- stg_sona__shifts
-- Thin wrapper over raw `shifts`: every shift on the rota, past and planned. Casts,
-- renames, de-duplicates, drops rows Sona has deleted.
--
-- Grain: one row per shift (id).
--
-- The connector re-reads a window of recent and upcoming shifts on every run and
-- marks shifts that disappeared from Sona with `_weld_deleted_at`. They are
-- filtered out here. If soft deletes are switched off for this stream the column
-- does not exist: remove that line, and know that deleted shifts will then stay in.
--
-- Times are UTC. Core converts them to each org unit's own time zone.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                      AS shift_id,
        CAST(start_datetime AS TIMESTAMP)       AS starts_at,
        CAST(finish_datetime AS TIMESTAMP)      AS finishes_at,
        CAST(org_unit_id AS STRING)             AS org_unit_id,
        CAST(shift_type_id AS STRING)           AS shift_type_id,
        CAST(shift_type_name AS STRING)         AS shift_type_name,
        CAST(category AS STRING)                AS category,
        CAST(filling_way AS STRING)             AS filling_way,
        CAST(employment_period_id AS STRING)    AS employment_period_id,
        CAST(user_working_shift_id AS STRING)   AS user_working_shift_id,
        CAST(agency_id AS STRING)               AS agency_id,
        CAST(draft_of_shift_id AS STRING)       AS draft_of_shift_id,
        COALESCE(CAST(is_travel_gap AS BOOL), FALSE) AS is_travel_gap,
        COALESCE(CAST(is_shift_run AS BOOL), FALSE)  AS is_shift_run,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{ source('sona', 'shifts') }}
    WHERE _weld_deleted_at IS NULL
)
WHERE row_rank = 1
