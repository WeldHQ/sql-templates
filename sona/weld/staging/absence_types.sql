-- staging.sona.absence_types
-- Thin wrapper over raw `absence_types`. Casts, renames, keeps the latest row.
-- Grain: one row per absence type.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                          AS absence_type_id,
        CAST(name AS STRING)                        AS absence_type_name,
        COALESCE(CAST(is_holiday AS BOOL), FALSE)   AS is_holiday,
        COALESCE(CAST(is_sickness AS BOOL), FALSE)  AS is_sickness,
        ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) AS row_rank
    FROM {{raw.sona.absence_types}}
)
WHERE row_rank = 1
