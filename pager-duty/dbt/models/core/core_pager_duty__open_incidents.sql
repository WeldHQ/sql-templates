-- core_pager_duty__open_incidents
-- Every incident that is not resolved yet, with its age: the Incidents page filtered
-- to Open, for a backlog dashboard or an alert on incidents left acknowledged for
-- days.
--
-- Grain: one row per open incident (current state as of the last sync).
-- Depends on: staging.pager_duty.raw_incident
--
-- Status comes from the analytics table, which the connector reads by last update,
-- so an old incident that was resolved recently drops out of this model on the
-- next sync.

SELECT
    incident_id,
    incident_number,
    title,
    status,
    urgency,
    priority_name,
    is_major,
    service_id,
    service_name,
    team_id,
    team_name,
    escalation_policy_name,
    created_at,
    TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), created_at, MINUTE) / 60.0      AS age_hours,
    first_acknowledged_user_id,
    seconds_to_first_ack IS NOT NULL                                    AS has_been_acknowledged,
    assignment_count,
    escalation_count,
    total_interruptions
FROM {{ ref('stg_pager_duty__raw_incident') }}
WHERE status != 'resolved'
