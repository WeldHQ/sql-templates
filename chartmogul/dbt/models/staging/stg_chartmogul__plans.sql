-- stg_chartmogul__plans
-- One row per ChartMogul plan, with its billing interval.

SELECT
    CAST(uuid AS STRING)              AS plan_uuid,
    CAST(name AS STRING)              AS plan_name,
    CAST(external_id AS STRING)       AS plan_external_id,
    CAST(data_source_uuid AS STRING)  AS data_source_uuid,
    CAST(interval_count AS INT64)     AS interval_count,
    LOWER(CAST(interval_unit AS STRING)) AS interval_unit
FROM {{ source('chartmogul', 'plans') }}
WHERE uuid IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY uuid ORDER BY _weld_synced DESC) = 1
