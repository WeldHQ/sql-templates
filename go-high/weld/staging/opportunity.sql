-- staging.go_high.opportunity
-- Thin wrapper over raw `opportunity`: one row per HighLevel opportunity (deal), current
-- state. Casts and renames.
--
-- Grain: opportunity_id.
-- `status` is open, won, lost or abandoned. `monetary_value` is the deal value you
-- entered, in the location's currency. Synced in full on every run.

SELECT
    CAST(id AS STRING)                          AS opportunity_id,
    CAST(location_id AS STRING)                 AS location_id,
    CAST(name AS STRING)                        AS opportunity_name,
    CAST(pipeline_id AS STRING)                 AS pipeline_id,
    CAST(pipeline_stage_id AS STRING)           AS pipeline_stage_id,
    CAST(contact_id AS STRING)                  AS contact_id,
    CAST(assigned_to AS STRING)                 AS assigned_user_id,
    LOWER(CAST(status AS STRING))               AS status,
    CAST(source AS STRING)                      AS source,
    CAST(lost_reason_id AS STRING)              AS lost_reason_id,
    CAST(monetary_value AS NUMERIC)             AS monetary_value,
    CAST(created_at AS TIMESTAMP)               AS created_at,
    CAST(updated_at AS TIMESTAMP)               AS updated_at,
    CAST(last_status_change_at AS TIMESTAMP)    AS last_status_change_at,
    CAST(last_stage_change_at AS TIMESTAMP)     AS last_stage_change_at
FROM {{raw.go_high.opportunity}}
