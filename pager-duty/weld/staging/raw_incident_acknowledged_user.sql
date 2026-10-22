-- staging.pager_duty.raw_incident_acknowledged_user
-- Thin wrapper over raw `raw_incident_acknowledged_user_id`: every user who
-- acknowledged an incident. Casts, renames, de-duplicates.
--
-- Grain: one row per incident x acknowledging user.

SELECT DISTINCT
    CAST(raw_incident_id AS STRING)         AS incident_id,
    CAST(acknowledged_user_id AS STRING)    AS user_id
FROM {{raw.pager_duty.raw_incident_acknowledged_user_id}}
WHERE acknowledged_user_id IS NOT NULL
