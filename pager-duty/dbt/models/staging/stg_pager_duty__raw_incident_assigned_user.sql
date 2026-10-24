-- stg_pager_duty__raw_incident_assigned_user
-- Thin wrapper over raw `raw_incident_assigned_user_id`: every user an incident was
-- assigned to over its life. Casts, renames, de-duplicates.
--
-- Grain: one row per incident x assigned user.

SELECT DISTINCT
    CAST(raw_incident_id AS STRING)     AS incident_id,
    CAST(assigned_user_id AS STRING)    AS user_id
FROM {{ source('pager_duty', 'raw_incident_assigned_user_id') }}
WHERE assigned_user_id IS NOT NULL
