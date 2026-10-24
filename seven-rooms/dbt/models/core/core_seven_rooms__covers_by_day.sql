-- core_seven_rooms__covers_by_day
-- Reservations, covers, cancellations, no-shows and spend per day, venue and
-- shift. The daily covers report a SevenRooms venue runs on.
-- Grain: reservation date x venue x shift category.
--
--   covers_booked   party size of reservations that were not canceled
--   covers_arrived  guests SevenRooms recorded as arrived
--   no_show_rate    no-shows over reservations that were not canceled
-- Rates are carried with their numerator and denominator; to roll up, sum both
-- and divide. Spend is in the venue's currency, and only reflects spend
-- SevenRooms knows about (prepayments, and POS checks if a POS is connected).
-- Future dates are included, so this also shows what is on the books.

SELECT
    r.reservation_date,
    r.venue_id,
    v.venue_name,
    v.currency,
    r.shift_category,
    COUNT(*)                                                       AS reservations,
    COUNTIF(r.outcome = 'canceled')                                AS canceled,
    COUNTIF(r.outcome = 'no_show')                                 AS no_shows,
    COUNTIF(r.outcome != 'canceled')                               AS reservations_not_canceled,
    SUM(IF(r.outcome != 'canceled', r.party_size, 0))              AS covers_booked,
    SUM(IF(r.outcome = 'booked', COALESCE(r.arrived_guests, 0), 0)) AS covers_arrived,
    SAFE_DIVIDE(COUNTIF(r.outcome = 'no_show'), COUNTIF(r.outcome != 'canceled')) AS no_show_rate,
    SAFE_DIVIDE(COUNTIF(r.outcome = 'canceled'), COUNT(*))         AS cancellation_rate,
    COUNTIF(r.is_vip AND r.outcome != 'canceled')                  AS vip_reservations,
    ROUND(SUM(r.net_spend), 2)                                     AS net_spend,
    ROUND(SUM(r.gross_spend), 2)                                   AS gross_spend,
    SAFE_DIVIDE(SUM(r.net_spend),
                SUM(IF(r.outcome = 'booked', COALESCE(r.arrived_guests, 0), 0))) AS net_spend_per_arrived_cover
FROM {{ ref('stg_seven_rooms__reservation') }} r
LEFT JOIN {{ ref('stg_seven_rooms__venue') }} v USING (venue_id)
GROUP BY 1, 2, 3, 4, 5
