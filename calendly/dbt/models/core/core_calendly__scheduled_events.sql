-- core_calendly__scheduled_events
-- Every scheduled meeting, classified, with its hosts, invitee outcomes and booking
-- lead time on one row.
--
-- Grain: one row per calendly_account x scheduled event.
-- Depends on: staging.calendly.scheduled_event, .scheduled_event_host, .invitee
--
-- This is the meeting-grain model the other reports read. Classify once here
-- rather than repeating the cancel / reschedule / no-show logic downstream.
--
-- OUTCOME is one of:
--   rescheduled   canceled because it was moved. Every canceled invitee on it has
--                 rescheduled = TRUE. Calendly's own analytics does not count
--                 these as cancellations, and neither does this model.
--   canceled      canceled for any other reason.
--   no_show       active, in the past, and every active invitee was marked a
--                 no-show.
--   completed     active and already over.
--   upcoming      active and not over yet.
-- A group meeting where only some invitees did not show is 'completed', with the
-- count in no_show_invitees.
--
-- No-shows are only as complete as your hosts' habit of marking them in Calendly.
-- 'completed' means "not canceled and not marked", not "attended".

WITH invitee_rollup AS (
    -- Aggregated to event grain BEFORE joining, so the host join below cannot fan
    -- invitee counts out.
    SELECT
        calendly_account,
        event_uri,
        COUNT(*)                                              AS invitees,
        COUNTIF(status = 'active')                            AS active_invitees,
        COUNTIF(status = 'canceled' AND is_rescheduled)       AS rescheduled_invitees,
        COUNTIF(status = 'canceled' AND NOT is_rescheduled)   AS canceled_invitees,
        COUNTIF(is_no_show)                                   AS no_show_invitees,
        COUNTIF(is_new_booking)                               AS new_bookings,
        MIN(booked_at)                                        AS first_booked_at
    FROM {{ ref('stg_calendly__invitee') }}
    GROUP BY 1, 2
),

host_rollup AS (
    SELECT
        calendly_account,
        event_uri,
        COUNT(*)                                              AS host_count,
        STRING_AGG(host_name, ', ' ORDER BY host_name)        AS host_names,
        STRING_AGG(host_email, ', ' ORDER BY host_email)      AS host_emails
    FROM {{ ref('stg_calendly__scheduled_event_host') }}
    GROUP BY 1, 2
),

latest_event_type_name AS (
    -- The event type list is not synced, so the most recent name a type was booked
    -- under stands in for its current name.
    SELECT
        calendly_account,
        event_type_uri,
        event_name AS event_type_name
    FROM {{ ref('stg_calendly__scheduled_event') }}
    WHERE event_type_uri IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY calendly_account, event_type_uri ORDER BY created_at DESC
    ) = 1
)

SELECT
    e.calendly_account,
    e.event_uri,
    e.event_type_uri,
    COALESCE(t.event_type_name, e.event_name)                 AS event_type_name,
    e.event_name,
    e.status,
    CASE
        WHEN e.status = 'canceled'
             AND COALESCE(i.rescheduled_invitees, 0) > 0
             AND COALESCE(i.canceled_invitees, 0) = 0         THEN 'rescheduled'
        WHEN e.status = 'canceled'                            THEN 'canceled'
        WHEN e.end_time > CURRENT_TIMESTAMP()                 THEN 'upcoming'
        -- Compared against active invitees: someone who canceled out of a group
        -- meeting cannot also have not shown up.
        WHEN COALESCE(i.active_invitees, 0) > 0
             AND i.no_show_invitees >= i.active_invitees      THEN 'no_show'
        ELSE 'completed'
    END                                                       AS outcome,

    e.start_time,
    e.end_time,
    TIMESTAMP_DIFF(e.end_time, e.start_time, MINUTE)          AS duration_minutes,
    e.created_at                                              AS booked_at,
    -- Lead time from the first booking to the meeting start. Can be negative when
    -- a host logs a meeting after the fact.
    TIMESTAMP_DIFF(e.start_time, COALESCE(i.first_booked_at, e.created_at), MINUTE) / 60.0
                                                              AS booking_lead_time_hours,
    e.location_type,

    h.host_count,
    h.host_names,
    h.host_emails,

    COALESCE(i.invitees, 0)                                   AS invitees,
    COALESCE(i.active_invitees, 0)                            AS active_invitees,
    COALESCE(i.canceled_invitees, 0)                          AS canceled_invitees,
    COALESCE(i.rescheduled_invitees, 0)                       AS rescheduled_invitees,
    COALESCE(i.no_show_invitees, 0)                           AS no_show_invitees,
    COALESCE(i.new_bookings, 0)                               AS new_bookings,
    e.invitees_limit,

    e.canceler_type,
    e.cancel_reason,
    e.canceled_at
FROM {{ ref('stg_calendly__scheduled_event') }} e
LEFT JOIN invitee_rollup i
    ON  i.calendly_account = e.calendly_account
    AND i.event_uri        = e.event_uri
LEFT JOIN host_rollup h
    ON  h.calendly_account = e.calendly_account
    AND h.event_uri        = e.event_uri
LEFT JOIN latest_event_type_name t
    ON  t.calendly_account = e.calendly_account
    AND t.event_type_uri   = e.event_type_uri
