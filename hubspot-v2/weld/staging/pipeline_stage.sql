-- staging.hubspot_v2.pipeline_stage
-- Thin wrapper over raw `pipeline_stage`. Grain: one row per pipeline x stage.
--
-- Stage ids are what deals store; the label is what people read. Core joins on
-- pipeline and stage together, so a stage can never be matched to the wrong
-- pipeline's label.
--
-- Only active pipelines are synced. A deal still sitting in a pipeline that has
-- since been archived keeps its stage id but finds no label here.

SELECT
    'portal_1'                                      AS hubspot_portal,
    CAST(pipeline_id AS STRING)                     AS pipeline_id,
    CAST(stage_id AS STRING)                        AS stage_id,
    NULLIF(TRIM(label), '')                         AS stage_label,
    CAST(display_order AS INT64)                    AS stage_display_order,
    -- Deal stages carry a win probability (0 to 1); ticket stages carry a state.
    CAST(metadata_probability AS FLOAT64)           AS stage_probability,
    CAST(metadata_isClosed AS BOOL)                 AS stage_is_closed,
    NOT COALESCE(archived, FALSE)                   AS stage_is_active
FROM {{raw.hubspot_v2.pipeline_stage}}
