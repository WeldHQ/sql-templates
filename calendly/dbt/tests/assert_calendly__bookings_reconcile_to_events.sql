-- Every original booking in the source funnel must also be counted as a new booking
-- on its scheduled event, and the other way round.
--
-- A difference usually means invitees whose scheduled event is missing from the
-- events table (a partial sync), or a reschedule chain that double counts.
-- Returns zero rows when they agree.

WITH funnel AS (
    SELECT calendly_account, SUM(bookings) AS bookings
    FROM {{ ref('core_calendly__bookings_by_source') }}
    GROUP BY 1
),

events AS (
    SELECT calendly_account, SUM(new_bookings) AS bookings
    FROM {{ ref('core_calendly__scheduled_events') }}
    GROUP BY 1
)

SELECT
    COALESCE(f.calendly_account, e.calendly_account) AS calendly_account,
    f.bookings AS funnel_bookings,
    e.bookings AS event_bookings
FROM funnel f
FULL OUTER JOIN events e USING (calendly_account)
WHERE COALESCE(f.bookings, 0) <> COALESCE(e.bookings, 0)
