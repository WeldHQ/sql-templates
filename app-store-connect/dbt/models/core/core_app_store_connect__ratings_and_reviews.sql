-- core_app_store_connect__ratings_and_reviews
-- Written reviews per day and territory: how many, average stars, how many were
-- negative, and how many you answered.
--
-- Grain: one row per review day (UTC) x app x territory (three-letter code).
-- Depends on: staging.app_store_connect.customer_reviews
--
-- Average rating is shipped as a sum and a count so it rolls up correctly. It
-- covers written reviews only; Apple's API does not return star-only ratings, so
-- this will not match the rating shown on your App Store page.
--
-- Territory is Apple's three-letter code ('USA'); the other models in this folder
-- use two-letter codes ('US'). Map one to the other before joining.

SELECT
    created_date                                        AS date_day,
    app_apple_id,
    territory_alpha3,

    COUNT(*)                                            AS reviews,
    SUM(rating)                                         AS rating_sum,
    ROUND(SAFE_DIVIDE(SUM(rating), COUNT(rating)), 2)   AS avg_rating,
    COUNTIF(rating >= 4)                                AS positive_reviews,
    COUNTIF(rating <= 2)                                AS negative_reviews,
    COUNTIF(response_id IS NOT NULL)                    AS reviews_replied,
    COUNTIF(rating <= 2 AND response_id IS NULL)        AS negative_reviews_unanswered
FROM {{ ref('stg_app_store_connect__customer_reviews') }}
GROUP BY created_date, app_apple_id, territory_alpha3
