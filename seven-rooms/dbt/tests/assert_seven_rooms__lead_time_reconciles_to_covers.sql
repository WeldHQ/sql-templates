-- Reservations per day and venue are the same in booking_lead_time and
-- covers_by_day, except for reservations without a created timestamp, which
-- booking_lead_time leaves out. So lead time can be lower, never higher.
-- Returns zero rows when it holds.

WITH covers AS (
    SELECT reservation_date, venue_id, SUM(reservations) AS reservations
    FROM {{ ref('core_seven_rooms__covers_by_day') }}
    GROUP BY 1, 2
),
lead AS (
    SELECT reservation_date, venue_id, SUM(reservations) AS reservations
    FROM {{ ref('core_seven_rooms__booking_lead_time') }}
    GROUP BY 1, 2
)

SELECT l.reservation_date, l.venue_id, l.reservations AS lead_reservations, c.reservations AS covers_reservations
FROM lead l
LEFT JOIN covers c USING (reservation_date, venue_id)
WHERE c.reservations IS NULL
   OR l.reservations > c.reservations
