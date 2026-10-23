-- In covers_by_day, canceled + not canceled = all reservations, and no-shows are
-- a subset of the reservations not canceled. Returns zero rows when it holds.

SELECT reservation_date, venue_id, shift_category, reservations, canceled, reservations_not_canceled, no_shows
FROM {{ ref('core_seven_rooms__covers_by_day') }}
WHERE canceled + reservations_not_canceled != reservations
   OR no_shows > reservations_not_canceled
