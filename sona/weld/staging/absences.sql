-- staging.sona.absences
-- Thin wrapper over raw `absences`: one row per absence (a holiday, a sickness
-- episode, ...), with its type. Casts, renames, de-duplicates.
--
-- Grain: one row per absence (id). The days it covers are in staging.sona.absence_days.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                          AS absence_id,
        CAST(user_id AS STRING)                     AS user_id,
        CAST(absence_type_id AS STRING)             AS absence_type_id,
        CAST(starts_at AS TIMESTAMP)                AS starts_at,
        CAST(ends_at AS TIMESTAMP)                  AS ends_at,
        COALESCE(CAST(is_open_ended AS BOOL), FALSE) AS is_open_ended,
        CAST(is_paid AS BOOL)                       AS is_paid,
        CAST(sick_note_provided AS BOOL)            AS sick_note_provided,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sona.absences}}
)
WHERE row_rank = 1
