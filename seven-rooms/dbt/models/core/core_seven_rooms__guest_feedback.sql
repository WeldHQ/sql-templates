-- core_seven_rooms__guest_feedback
-- Guest feedback scores per venue and visit date: overall, food, drinks, service
-- and ambience.
-- Grain: reservation date x venue x feedback type.
--
-- Each score is carried as a sum and a count of answers, because guests skip
-- questions: average over any period as SUM(<x>_total) / SUM(<x>_responses).
-- The avg_ columns are for this row only.

SELECT
    reservation_date,
    venue_id,
    feedback_type,
    COUNT(*)                                       AS feedback_received,
    SUM(overall_rating)                            AS overall_total,
    COUNT(overall_rating)                          AS overall_responses,
    SAFE_DIVIDE(SUM(overall_rating), COUNT(overall_rating))   AS avg_overall,
    SUM(food_rating)                               AS food_total,
    COUNT(food_rating)                             AS food_responses,
    SAFE_DIVIDE(SUM(food_rating), COUNT(food_rating))         AS avg_food,
    SUM(drinks_rating)                             AS drinks_total,
    COUNT(drinks_rating)                           AS drinks_responses,
    SAFE_DIVIDE(SUM(drinks_rating), COUNT(drinks_rating))     AS avg_drinks,
    SUM(service_rating)                            AS service_total,
    COUNT(service_rating)                          AS service_responses,
    SAFE_DIVIDE(SUM(service_rating), COUNT(service_rating))   AS avg_service,
    SUM(ambience_rating)                           AS ambience_total,
    COUNT(ambience_rating)                         AS ambience_responses,
    SAFE_DIVIDE(SUM(ambience_rating), COUNT(ambience_rating)) AS avg_ambience,
    COUNTIF(LOWER(recommend_to_friend) IN ('true', 'yes', '1')) AS would_recommend,
    COUNT(recommend_to_friend)                     AS recommend_responses
FROM {{ ref('stg_seven_rooms__reservation_feedback') }}
GROUP BY 1, 2, 3
