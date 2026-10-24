-- core_calendly__meetings_by_day
-- Calendly's "Scheduled events" analytics per host and event type, as a daily
-- time series: what was booked, what took place, what was canceled or no-showed.
--
-- Grain: day x calendly_account x host x event type.
-- Depends on: core.calendly.scheduled_events, staging.calendly.scheduled_event_host,
--             staging.calendly.organization_membership
--
-- TWO DATE AXES, NAMED APART. `booked_meetings` lands on the day the meeting was
-- booked. Every other measure lands on the day the meeting was scheduled to take
-- place. Calendly's analytics page offers the same toggle; mixing them in one
-- column is how a team ends up arguing about a number that is right twice.
--
-- HOSTS FAN OUT ON PURPOSE. A collective meeting with three hosts is one meeting in
-- each host's row. Summing across hosts therefore overcounts group meetings; for
-- organisation totals read core.calendly.scheduled_events directly, or sum
-- org_meetings_scheduled, which counts each meeting once (on its first host
-- alphabetically).
--
-- TIME ZONE: days are cut in UTC. Change the 'UTC' literal in the first CTE to
-- your reporting zone (e.g. 'Europe/Copenhagen') if late-evening meetings land on
-- the wrong day.
--
-- Built on a spine of every observed host x event type pair, so a quiet day returns
-- zeros instead of a gap a line chart would interpolate over.

WITH params AS (
    SELECT 'UTC' AS tz
),

meeting_host AS (
    SELECT
        e.*,
        h.host_user_uri,
        h.host_name,
        h.host_email,
        -- One host per meeting carries the org-level count, so it can be summed
        -- across hosts without double counting.
        ROW_NUMBER() OVER (
            PARTITION BY e.calendly_account, e.event_uri ORDER BY h.host_name, h.host_user_uri
        ) = 1                                                    AS is_first_host,
        DATE(e.start_time, p.tz)                                 AS meeting_date,
        DATE(e.booked_at, p.tz)                                  AS booked_date
    FROM {{ ref('core_calendly__scheduled_events') }} e
    CROSS JOIN params p
    LEFT JOIN {{ ref('stg_calendly__scheduled_event_host') }} h
        ON  h.calendly_account = e.calendly_account
        AND h.event_uri        = e.event_uri
),

by_meeting_date AS (
    SELECT
        calendly_account,
        COALESCE(host_user_uri, 'unknown')                       AS host_user_uri,
        COALESCE(event_type_uri, 'unknown')                      AS event_type_uri,
        meeting_date                                             AS date,
        COUNT(*)                                                 AS meetings_scheduled,
        COUNTIF(is_first_host)                                   AS org_meetings_scheduled,
        COUNTIF(outcome = 'completed')                           AS meetings_completed,
        COUNTIF(outcome = 'upcoming')                            AS meetings_upcoming,
        COUNTIF(outcome = 'canceled')                            AS meetings_canceled,
        COUNTIF(outcome = 'canceled' AND canceler_type = 'host') AS meetings_canceled_by_host,
        COUNTIF(outcome = 'rescheduled')                         AS meetings_rescheduled,
        COUNTIF(outcome = 'no_show')                             AS meetings_no_show,
        SUM(no_show_invitees)                                    AS no_show_invitees,
        SUM(IF(outcome = 'completed', duration_minutes, 0))      AS completed_minutes
    FROM meeting_host
    WHERE meeting_date IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

by_booked_date AS (
    SELECT
        calendly_account,
        COALESCE(host_user_uri, 'unknown')                       AS host_user_uri,
        COALESCE(event_type_uri, 'unknown')                      AS event_type_uri,
        booked_date                                              AS date,
        COUNT(*)                                                 AS booked_meetings,
        SUM(booking_lead_time_hours)                             AS booked_lead_time_hours_sum
    FROM meeting_host
    WHERE booked_date IS NOT NULL
    GROUP BY 1, 2, 3, 4
),

pairs AS (
    SELECT calendly_account, host_user_uri, event_type_uri FROM by_meeting_date
    UNION DISTINCT
    SELECT calendly_account, host_user_uri, event_type_uri FROM by_booked_date
),

date_spine AS (
    SELECT date
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT LEAST(MIN(meeting_date), MIN(booked_date)) FROM meeting_host),
        (SELECT GREATEST(MAX(meeting_date), CURRENT_DATE()) FROM meeting_host),
        INTERVAL 1 DAY
    )) AS date
),

host_names AS (
    -- Current members take their name from the membership list; hosts who have
    -- since left the organisation keep the name on their most recent meeting.
    SELECT
        l.calendly_account,
        l.host_user_uri,
        COALESCE(om.user_name, l.host_name)   AS host_name,
        COALESCE(om.user_email, l.host_email) AS host_email,
        om.role                               AS host_role,
        om.user_uri IS NOT NULL               AS host_is_current_member
    FROM (
        SELECT calendly_account, host_user_uri, host_name, host_email
        FROM meeting_host
        WHERE host_user_uri IS NOT NULL
        QUALIFY ROW_NUMBER() OVER (
            PARTITION BY calendly_account, host_user_uri ORDER BY start_time DESC
        ) = 1
    ) l
    LEFT JOIN {{ ref('stg_calendly__organization_membership') }} om
        ON  om.calendly_account = l.calendly_account
        AND om.user_uri         = l.host_user_uri
),

event_type_names AS (
    SELECT DISTINCT calendly_account, event_type_uri, event_type_name
    FROM {{ ref('core_calendly__scheduled_events') }}
    WHERE event_type_uri IS NOT NULL
)

SELECT
    d.date,
    p.calendly_account,
    p.host_user_uri,
    hn.host_name,
    hn.host_email,
    hn.host_role,
    hn.host_is_current_member,
    p.event_type_uri,
    et.event_type_name,

    COALESCE(b.booked_meetings, 0)              AS booked_meetings,
    -- Sum, not average, so it re-aggregates: divide by booked_meetings in BI.
    COALESCE(b.booked_lead_time_hours_sum, 0)   AS booked_lead_time_hours_sum,

    COALESCE(m.meetings_scheduled, 0)           AS meetings_scheduled,
    COALESCE(m.org_meetings_scheduled, 0)       AS org_meetings_scheduled,
    COALESCE(m.meetings_completed, 0)           AS meetings_completed,
    COALESCE(m.meetings_upcoming, 0)            AS meetings_upcoming,
    COALESCE(m.meetings_canceled, 0)            AS meetings_canceled,
    COALESCE(m.meetings_canceled_by_host, 0)    AS meetings_canceled_by_host,
    COALESCE(m.meetings_rescheduled, 0)         AS meetings_rescheduled,
    COALESCE(m.meetings_no_show, 0)             AS meetings_no_show,
    COALESCE(m.no_show_invitees, 0)             AS no_show_invitees,
    COALESCE(m.completed_minutes, 0)            AS completed_minutes
FROM pairs p
CROSS JOIN date_spine d
LEFT JOIN by_meeting_date m
    ON  m.calendly_account = p.calendly_account
    AND m.host_user_uri    = p.host_user_uri
    AND m.event_type_uri   = p.event_type_uri
    AND m.date             = d.date
LEFT JOIN by_booked_date b
    ON  b.calendly_account = p.calendly_account
    AND b.host_user_uri    = p.host_user_uri
    AND b.event_type_uri   = p.event_type_uri
    AND b.date             = d.date
LEFT JOIN host_names hn
    ON  hn.calendly_account = p.calendly_account
    AND hn.host_user_uri    = p.host_user_uri
LEFT JOIN event_type_names et
    ON  et.calendly_account = p.calendly_account
    AND et.event_type_uri   = p.event_type_uri
