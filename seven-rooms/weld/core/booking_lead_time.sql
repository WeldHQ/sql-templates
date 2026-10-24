-- core.seven_rooms.booking_lead_time
-- How far ahead guests book, by who took the booking and the reservation type.
-- Grain: reservation date x venue x booked by x reservation type x lead time band.
--
-- Lead time is days between the booking being created and the reservation date.
-- booked_by is the SevenRooms user or channel recorded on the reservation, as
-- SevenRooms names it; reservation_type is SevenRooms' own field. Canceled
-- reservations are included and counted separately, since late cancellations
-- are part of the picture.

WITH bookings AS (
    SELECT
        *,
        DATE_DIFF(reservation_date, DATE(created_at), DAY) AS lead_days
    FROM {{staging.seven_rooms.reservation}}
    WHERE created_at IS NOT NULL
)

SELECT
    reservation_date,
    venue_id,
    booked_by,
    reservation_type,
    CASE
        WHEN lead_days <= 0  THEN 'same_day'
        WHEN lead_days <= 2  THEN '1_2_days'
        WHEN lead_days <= 7  THEN '3_7_days'
        WHEN lead_days <= 30 THEN '8_30_days'
        ELSE 'over_30_days'
    END                                         AS lead_time_band,
    COUNT(*)                                    AS reservations,
    COUNTIF(outcome = 'canceled')               AS canceled,
    COUNTIF(outcome = 'no_show')                AS no_shows,
    SUM(IF(outcome != 'canceled', party_size, 0)) AS covers_booked,
    SUM(GREATEST(lead_days, 0))                 AS lead_days_total
FROM bookings
GROUP BY 1, 2, 3, 4, 5
