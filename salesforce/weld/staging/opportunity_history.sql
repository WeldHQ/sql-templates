-- staging.salesforce.opportunity_history
-- Thin wrapper over raw `opportunity_history`. Casts, renames, drops deleted rows.
-- Grain: one row per change.
--
-- OpportunityHistory is Salesforce's built-in audit of the pipeline fields. A row
-- is written when an opportunity is created and each time its stage, amount,
-- probability, close date or forecast category changes, and every row carries the
-- full set of those values as they stood after the change. It needs no field
-- history tracking setup, but it is a separate object: select it in the sync, or
-- core.salesforce.opportunity_stage_history will fail to build.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS history_id,
    CAST(opportunity_id AS STRING)                 AS opportunity_id,
    NULLIF(TRIM(CAST(stage_name AS STRING)), '')   AS stage_name,
    CAST(amount AS FLOAT64)                        AS amount,
    CAST(probability AS FLOAT64)                   AS probability_percent,
    DATE(CAST(close_date AS TIMESTAMP))            AS close_date,
    CAST(forecast_category AS STRING)              AS forecast_category,
    CAST(created_by_id AS STRING)                  AS changed_by_id,
    CAST(created_date AS TIMESTAMP)                AS changed_at
FROM {{raw.salesforce.opportunity_history}}
WHERE NOT COALESCE(is_deleted, FALSE)
