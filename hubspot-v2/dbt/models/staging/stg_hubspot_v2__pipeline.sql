-- stg_hubspot_v2__pipeline
-- Thin wrapper over raw `pipeline`. Grain: one row per pipeline.
-- Holds both deal and ticket pipelines; `object_type` tells them apart.

SELECT
    'portal_1'                        AS hubspot_portal,
    CAST(pipeline_id AS STRING)       AS pipeline_id,
    NULLIF(TRIM(label), '')           AS pipeline_label,
    LOWER(CAST(type AS STRING))       AS object_type,
    CAST(display_order AS INT64)      AS pipeline_display_order
FROM {{ source('hubspot_v2', 'pipeline') }}
