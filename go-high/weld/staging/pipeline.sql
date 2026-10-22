-- staging.go_high.pipeline
-- Thin wrapper over raw `pipeline`: one row per HighLevel pipeline. Casts and renames.
--
-- Grain: pipeline_id.

SELECT
    CAST(id AS STRING)                          AS pipeline_id,
    CAST(location_id AS STRING)                 AS location_id,
    CAST(name AS STRING)                        AS pipeline_name
FROM {{raw.go_high.pipeline}}
