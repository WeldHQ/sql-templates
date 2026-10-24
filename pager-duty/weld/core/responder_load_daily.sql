-- core.pager_duty.responder_load_daily
-- How much incident work lands on each responder: incidents assigned to them,
-- acknowledged by them and resolved by them. The per-person view of PagerDuty's
-- Responder report, for spotting the people carrying the on-call load.
--
-- Grain: one row per incident creation day (UTC) x user.
-- Depends on: staging.pager_duty.raw_incident, .raw_incident_assigned_user,
--             .raw_incident_acknowledged_user, .user
--
-- An incident assigned to three people counts once for each of them, so this model
-- does not sum to incident_response_daily across users; that is the point of it.
--
-- The `_with_off_hour_interruptions` and `_with_sleep_hour_interruptions` columns
-- count assigned incidents that interrupted someone outside working or sleeping
-- hours. PagerDuty reports interruptions per incident, not per responder, so the
-- person interrupted may have been a colleague on the same incident.

WITH involvement AS (
    SELECT incident_id, user_id, 'assigned' AS role FROM {{staging.pager_duty.raw_incident_assigned_user}}
    UNION ALL
    SELECT incident_id, user_id, 'acknowledged' AS role FROM {{staging.pager_duty.raw_incident_acknowledged_user}}
    UNION ALL
    SELECT incident_id, resolved_by_user_id AS user_id, 'resolved' AS role
    FROM {{staging.pager_duty.raw_incident}}
    WHERE resolved_by_user_id IS NOT NULL
)

SELECT
    i.created_date                                                  AS date_day,
    v.user_id,
    ANY_VALUE(u.user_name)                                          AS user_name,
    ANY_VALUE(u.time_zone)                                          AS user_time_zone,

    COUNT(DISTINCT IF(v.role = 'assigned', v.incident_id, NULL))    AS incidents_assigned,
    COUNT(DISTINCT IF(v.role = 'acknowledged', v.incident_id, NULL)) AS incidents_acknowledged,
    COUNT(DISTINCT IF(v.role = 'resolved', v.incident_id, NULL))    AS incidents_resolved,
    COUNT(DISTINCT IF(v.role = 'assigned' AND i.urgency = 'high', v.incident_id, NULL))
                                                                    AS high_urgency_incidents_assigned,
    COUNT(DISTINCT IF(v.role = 'assigned' AND i.off_hour_interruptions > 0, v.incident_id, NULL))
                                                                    AS incidents_assigned_with_off_hour_interruptions,
    COUNT(DISTINCT IF(v.role = 'assigned' AND i.sleep_hour_interruptions > 0, v.incident_id, NULL))
                                                                    AS incidents_assigned_with_sleep_hour_interruptions
FROM involvement v
JOIN {{staging.pager_duty.raw_incident}} i
  ON i.incident_id = v.incident_id
LEFT JOIN {{staging.pager_duty.user}} u
  ON u.user_id = v.user_id
GROUP BY i.created_date, v.user_id
