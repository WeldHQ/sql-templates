-- stg_mixpanel_source__funnel_step
-- Thin wrapper over raw `funnels`: unpacks the `steps` JSON on each saved funnel's daily
-- result into one row per step. Casts. De-duplicates restated days.
--
-- Grain: funnel_id x date x step_number.
-- Mixpanel computes these for your saved funnels; each `date` is the day users entered
-- the funnel. Mixpanel keeps restating recent days as late conversions land, and the
-- stream is incremental on `date`, so the latest synced copy of each funnel day is kept.
-- Step fields are as Mixpanel's Funnels API returns them: `count` users reaching the
-- step, `step_conv_ratio` from the previous step, `overall_conv_ratio` from step one,
-- `avg_time` seconds from the previous step.

WITH latest AS (
    SELECT *
    FROM {{ source('mixpanel_source', 'funnels') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY funnel_id, date ORDER BY _weld_synced DESC) = 1
)

SELECT
    CAST(latest.funnel_id AS INT64)                                     AS funnel_id,
    CAST(latest.name AS STRING)                                         AS funnel_name,
    SAFE_CAST(latest.date AS DATE)                                      AS date,
    step_offset + 1                                                     AS step_number,
    JSON_VALUE(step, '$.event')                                         AS step_event,
    COALESCE(JSON_VALUE(step, '$.step_label'), JSON_VALUE(step, '$.event')) AS step_label,
    SAFE_CAST(JSON_VALUE(step, '$.count') AS INT64)                     AS users,
    SAFE_CAST(JSON_VALUE(step, '$.step_conv_ratio') AS FLOAT64)         AS step_conversion,
    SAFE_CAST(JSON_VALUE(step, '$.overall_conv_ratio') AS FLOAT64)      AS overall_conversion,
    SAFE_CAST(JSON_VALUE(step, '$.avg_time') AS FLOAT64)                AS avg_seconds_from_previous_step,
    SAFE_CAST(JSON_VALUE(step, '$.avg_time_from_start') AS FLOAT64)     AS avg_seconds_from_start
FROM latest,
     UNNEST(JSON_QUERY_ARRAY(SAFE.PARSE_JSON(latest.steps))) AS step WITH OFFSET AS step_offset
