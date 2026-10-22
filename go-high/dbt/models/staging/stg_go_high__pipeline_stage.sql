-- stg_go_high__pipeline_stage
-- Thin wrapper over raw `pipeline_stage`: the stages of each pipeline, in board order.
-- Casts and renames.
--
-- Grain: pipeline_stage_id.

SELECT
    CAST(id AS STRING)                          AS pipeline_stage_id,
    CAST(pipeline_id AS STRING)                 AS pipeline_id,
    CAST(name AS STRING)                        AS stage_name,
    CAST(position AS INT64)                     AS stage_position
FROM {{ source('go_high', 'pipeline_stage') }}
