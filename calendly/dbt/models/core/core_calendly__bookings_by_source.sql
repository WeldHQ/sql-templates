-- core_calendly__bookings_by_source
-- Where bookings come from and what became of them: new bookings by UTM source,
-- medium and campaign, followed through any reschedules to their final outcome.
--
-- Grain: booking month x calendly_account x utm_source x utm_medium x utm_campaign
--        x event type.
-- Depends on: staging.calendly.invitee, core.calendly.scheduled_events
--
-- ONE BOOKING, ONE ROW OF FUNNEL. A reschedule in Calendly cancels the invitee and
-- creates a new one, so counting invitee rows counts a meeting moved twice as three
-- bookings, two of them "canceled". This model starts from the original booking
-- (is_new_booking), walks the old_invitee -> new_invitee chain to the last
-- invitee, and takes the outcome from there. Source, booking month and event type
-- stay those of the ORIGINAL booking, because that is the click you are measuring.
--
-- UTM values come from the tracking parameters on the booking link. A booking
-- without them groups under '(not set)'. Calendly only records what was on the URL:
-- an embed or a link shared without UTM parameters lands in '(not set)' however the
-- visitor actually arrived.
--
-- TIME ZONE: months are cut in UTC. Change the 'UTC' literal to your reporting zone.

WITH RECURSIVE chain AS (
    SELECT
        i.calendly_account,
        i.invitee_uri                 AS original_invitee_uri,
        i.invitee_uri                 AS current_invitee_uri,
        i.new_invitee_uri             AS next_invitee_uri,
        0                             AS reschedules
    FROM {{ ref('stg_calendly__invitee') }} i
    WHERE i.is_new_booking

    UNION ALL

    SELECT
        c.calendly_account,
        c.original_invitee_uri,
        n.invitee_uri,
        n.new_invitee_uri,
        c.reschedules + 1
    FROM chain c
    JOIN {{ ref('stg_calendly__invitee') }} n
        ON  n.calendly_account = c.calendly_account
        AND n.invitee_uri      = c.next_invitee_uri
    -- Guard against a malformed loop in the reschedule links.
    WHERE c.reschedules < 50
),

final_invitee AS (
    SELECT *
    FROM chain
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY calendly_account, original_invitee_uri ORDER BY reschedules DESC
    ) = 1
),

booking AS (
    SELECT
        o.calendly_account,
        DATE_TRUNC(DATE(o.booked_at, 'UTC'), MONTH)             AS booking_month,
        COALESCE(o.utm_source, '(not set)')                     AS utm_source,
        COALESCE(o.utm_medium, '(not set)')                     AS utm_medium,
        COALESCE(o.utm_campaign, '(not set)')                   AS utm_campaign,
        COALESCE(oe.event_type_uri, 'unknown')                  AS event_type_uri,
        oe.event_type_name,
        o.routing_form_submission_uri IS NOT NULL               AS via_routing_form,
        f.reschedules,
        CASE
            WHEN l.status = 'canceled'                          THEN 'canceled'
            WHEN le.end_time > CURRENT_TIMESTAMP()              THEN 'upcoming'
            WHEN l.is_no_show                                   THEN 'no_show'
            ELSE 'completed'
        END                                                     AS final_outcome,
        TIMESTAMP_DIFF(le.start_time, o.booked_at, MINUTE) / 60.0 AS lead_time_hours
    FROM final_invitee f
    JOIN {{ ref('stg_calendly__invitee') }} o
        ON  o.calendly_account = f.calendly_account
        AND o.invitee_uri      = f.original_invitee_uri
    JOIN {{ ref('stg_calendly__invitee') }} l
        ON  l.calendly_account = f.calendly_account
        AND l.invitee_uri      = f.current_invitee_uri
    LEFT JOIN {{ ref('core_calendly__scheduled_events') }} oe
        ON  oe.calendly_account = o.calendly_account
        AND oe.event_uri        = o.event_uri
    LEFT JOIN {{ ref('core_calendly__scheduled_events') }} le
        ON  le.calendly_account = l.calendly_account
        AND le.event_uri        = l.event_uri
)

SELECT
    booking_month,
    calendly_account,
    utm_source,
    utm_medium,
    utm_campaign,
    event_type_uri,
    ANY_VALUE(event_type_name)                       AS event_type_name,

    COUNT(*)                                         AS bookings,
    COUNTIF(via_routing_form)                        AS bookings_via_routing_form,
    COUNTIF(reschedules > 0)                         AS bookings_rescheduled,
    COUNTIF(final_outcome = 'completed')             AS bookings_completed,
    COUNTIF(final_outcome = 'upcoming')              AS bookings_upcoming,
    COUNTIF(final_outcome = 'canceled')              AS bookings_canceled,
    COUNTIF(final_outcome = 'no_show')               AS bookings_no_show,
    -- Show rate over decided bookings only: upcoming ones have not had the chance
    -- to show yet, and counting them would drag the current month down.
    SAFE_DIVIDE(
        COUNTIF(final_outcome = 'completed'),
        COUNTIF(final_outcome IN ('completed', 'no_show', 'canceled'))
    )                                                AS show_rate,
    -- Sum, so it re-aggregates across rows; divide by bookings in BI.
    SUM(lead_time_hours)                             AS lead_time_hours_sum
FROM booking
GROUP BY 1, 2, 3, 4, 5, 6
