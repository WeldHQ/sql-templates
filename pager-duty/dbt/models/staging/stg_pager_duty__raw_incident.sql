-- stg_pager_duty__raw_incident
-- Thin wrapper over raw `raw_incident`: one row per incident from PagerDuty's
-- Analytics API, with the response timings PagerDuty computes itself. Casts,
-- renames, keeps the latest row per incident.
--
-- Grain: one row per incident.
--
-- This is the table to report from, rather than `incident`. The connector reads it
-- by last update, so an incident that resolves weeks after it was created still has
-- its final status and timings here. All timestamps are UTC.

SELECT * EXCEPT (row_rank)
FROM (
    SELECT
        CAST(id AS STRING)                              AS incident_id,
        CAST(incident_number AS INT64)                  AS incident_number,
        CAST(description AS STRING)                     AS title,
        LOWER(CAST(status AS STRING))                   AS status,
        LOWER(CAST(urgency AS STRING))                  AS urgency,
        COALESCE(CAST(major AS BOOL), CAST(major_incident AS BOOL), FALSE) AS is_major,
        COALESCE(CAST(auto_resolved AS BOOL), FALSE)    AS is_auto_resolved,

        CAST(created_at AS TIMESTAMP)                   AS created_at,
        DATE(CAST(created_at AS TIMESTAMP))             AS created_date,
        CAST(resolved_at AS TIMESTAMP)                  AS resolved_at,
        CAST(updated_at AS TIMESTAMP)                   AS updated_at,

        CAST(service_id AS STRING)                      AS service_id,
        CAST(service_name AS STRING)                    AS service_name,
        CAST(team_id AS STRING)                         AS team_id,
        CAST(team_name AS STRING)                       AS team_name,
        CAST(escalation_policy_id AS STRING)            AS escalation_policy_id,
        CAST(escalation_policy_name AS STRING)          AS escalation_policy_name,
        CAST(priority_name AS STRING)                   AS priority_name,
        CAST(priority_order AS INT64)                   AS priority_order,
        CAST(incident_type_name AS STRING)              AS incident_type_name,

        CAST(resolved_by_user_id AS STRING)             AS resolved_by_user_id,
        CAST(first_acknowledged_user_id AS STRING)      AS first_acknowledged_user_id,

        -- PagerDuty's own timings, in seconds. NULL when the step never happened
        -- (an incident nobody acknowledged has no seconds_to_first_ack).
        CAST(seconds_to_first_ack AS INT64)             AS seconds_to_first_ack,
        CAST(seconds_to_engage AS INT64)                AS seconds_to_engage,
        CAST(seconds_to_mobilize AS INT64)              AS seconds_to_mobilize,
        CAST(seconds_to_resolve AS INT64)               AS seconds_to_resolve,
        CAST(engaged_seconds AS INT64)                  AS engaged_seconds,
        CAST(snoozed_seconds AS INT64)                  AS snoozed_seconds,

        CAST(assignment_count AS INT64)                 AS assignment_count,
        CAST(reassignment_count AS INT64)               AS reassignment_count,
        CAST(escalation_count AS INT64)                 AS escalation_count,
        CAST(manual_escalation_count AS INT64)          AS manual_escalation_count,
        CAST(timeout_escalation_count AS INT64)         AS timeout_escalation_count,
        CAST(engaged_user_count AS INT64)               AS engaged_user_count,

        -- Interruptions are notifications that reached a responder, split by when
        -- they landed relative to the responder's own working and sleeping hours.
        CAST(business_hour_interruptions AS INT64)      AS business_hour_interruptions,
        CAST(off_hour_interruptions AS INT64)           AS off_hour_interruptions,
        CAST(sleep_hour_interruptions AS INT64)         AS sleep_hour_interruptions,
        CAST(total_interruptions AS INT64)              AS total_interruptions,
        CAST(total_notifications AS INT64)              AS total_notifications,

        ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC, _weld_synced DESC) AS row_rank
    FROM {{ source('pager_duty', 'raw_incident') }}
)
WHERE row_rank = 1
