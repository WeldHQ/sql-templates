-- core.pager_duty.incident_response_daily
-- Incident volume and response times per service and team: PagerDuty's Service
-- Performance and Team Performance reports, by day. Mean time to acknowledge (MTTA),
-- mean time to resolve (MTTR), escalations, auto-resolves and the interruption load
-- on responders.
--
-- Grain: one row per incident creation day (UTC) x service x team x urgency x priority.
-- Depends on: staging.pager_duty.raw_incident
--
-- MEANS ARE SHIPPED AS SUMS AND COUNTS. Every timing comes with its total seconds
-- and the number of incidents it covers, and the mean in the same row is the one
-- divided by the other. To roll up to a week or a whole team, sum both and divide
-- again; averaging the mean column weights a day with one incident the same as a
-- day with a hundred.
--
-- Incidents are dated on creation, as PagerDuty's reports are. An incident
-- resolved on a later day still counts on the day it started, so the most recent
-- days have open incidents in them and their MTTR rises as those resolve.

SELECT
    created_date                                                AS date_day,
    service_id,
    ANY_VALUE(service_name)                                     AS service_name,
    team_id,
    ANY_VALUE(team_name)                                        AS team_name,
    urgency,
    priority_name,

    COUNT(*)                                                    AS incidents,
    COUNTIF(is_major)                                           AS major_incidents,
    COUNTIF(status = 'resolved')                                AS resolved_incidents,
    COUNTIF(status != 'resolved')                               AS open_incidents,
    COUNTIF(is_auto_resolved)                                   AS auto_resolved_incidents,

    -- Time to acknowledge.
    COUNTIF(seconds_to_first_ack IS NOT NULL)                   AS acknowledged_incidents,
    SUM(seconds_to_first_ack)                                   AS total_seconds_to_first_ack,
    ROUND(SAFE_DIVIDE(SUM(seconds_to_first_ack),
                      COUNTIF(seconds_to_first_ack IS NOT NULL)) / 60, 2) AS mtta_minutes,

    -- Time to resolve, over resolved incidents only.
    COUNTIF(seconds_to_resolve IS NOT NULL)                     AS incidents_with_resolve_time,
    SUM(seconds_to_resolve)                                     AS total_seconds_to_resolve,
    ROUND(SAFE_DIVIDE(SUM(seconds_to_resolve),
                      COUNTIF(seconds_to_resolve IS NOT NULL)) / 60, 2)   AS mttr_minutes,

    -- Escalations: an incident that escalated on timeout means nobody on the first
    -- level acknowledged in time, which is the clearest signal of on-call trouble.
    SUM(escalation_count)                                       AS escalations,
    SUM(timeout_escalation_count)                               AS timeout_escalations,
    SUM(manual_escalation_count)                                AS manual_escalations,
    COUNTIF(timeout_escalation_count > 0)                       AS incidents_escalated_on_timeout,
    SUM(reassignment_count)                                     AS reassignments,

    -- Responder load.
    SUM(total_notifications)                                    AS notifications,
    SUM(total_interruptions)                                    AS interruptions,
    SUM(business_hour_interruptions)                            AS business_hour_interruptions,
    SUM(off_hour_interruptions)                                 AS off_hour_interruptions,
    SUM(sleep_hour_interruptions)                               AS sleep_hour_interruptions,
    SUM(engaged_seconds)                                        AS engaged_seconds,

    ROUND(SAFE_DIVIDE(COUNTIF(is_auto_resolved), COUNT(*)), 4)  AS auto_resolve_rate
FROM {{staging.pager_duty.raw_incident}}
GROUP BY created_date, service_id, team_id, urgency, priority_name
