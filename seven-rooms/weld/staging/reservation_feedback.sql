-- staging.seven_rooms.reservation_feedback
-- Thin wrapper over raw `reservation_feedback`. One row per guest feedback
-- submission.
--
-- Ratings arrive as text and are cast to numbers; anything that is not a number
-- becomes NULL. Feedback that is not tied to a reservation (for example on an
-- online order) has reservation_id 'unknown'.

SELECT
    CAST(reservation_id AS STRING)                  AS reservation_id,
    CAST(venue_id AS STRING)                        AS venue_id,
    CAST(feedback_type AS STRING)                   AS feedback_type,
    DATE(CAST(reservation_date AS TIMESTAMP))       AS reservation_date,
    CAST(created_date AS TIMESTAMP)                 AS created_at,
    SAFE_CAST(CAST(overall AS STRING) AS FLOAT64)   AS overall_rating,
    SAFE_CAST(CAST(food AS STRING) AS FLOAT64)      AS food_rating,
    SAFE_CAST(CAST(drinks AS STRING) AS FLOAT64)    AS drinks_rating,
    SAFE_CAST(CAST(service AS STRING) AS FLOAT64)   AS service_rating,
    SAFE_CAST(CAST(ambience AS STRING) AS FLOAT64)  AS ambience_rating,
    CAST(recommend_to_friend AS STRING)             AS recommend_to_friend
FROM {{raw.seven_rooms.reservation_feedback}}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(reservation_id AS STRING), CAST(venue_id AS STRING), CAST(created_date AS STRING)
    ORDER BY _weld_synced DESC
) = 1
