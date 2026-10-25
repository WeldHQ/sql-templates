-- stg_salesforce__opportunity_stage
-- Thin wrapper over raw `opportunity_stage`: the org's stage picklist with the
-- settings behind each value. Grain: one row per stage.
--
-- stage_name on an opportunity holds the stage's API name, so that is the join
-- key. sort_order is the order the stages appear in Setup, which is what
-- "moving backwards" is measured against.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS stage_id,
    CAST(api_name AS STRING)                       AS stage_name,
    CAST(master_label AS STRING)                   AS stage_label,
    CAST(sort_order AS INT64)                      AS stage_sort_order,
    CAST(is_active AS BOOL)                        AS stage_is_active,
    CAST(is_closed AS BOOL)                        AS stage_is_closed,
    CAST(is_won AS BOOL)                           AS stage_is_won,
    CAST(forecast_category_name AS STRING)         AS stage_forecast_category,
    CAST(default_probability AS FLOAT64)           AS stage_default_probability_percent
FROM {{ source('salesforce', 'opportunity_stage') }}
