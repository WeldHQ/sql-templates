-- core.google_my_business_profile.reviews_monthly
-- Review volume, rating and response per location per month, plus the running
-- review count and average rating as of each month end.
--
-- Grain: month x location_id, every month from a location's first review to the
-- current month (months without reviews are kept so the running figures are
-- continuous).
-- Depends on: staging.google_my_business_profile.review, .location
--
-- The running average is rebuilt from the reviews still on the profile. Google
-- removes deleted and filtered reviews from the API, so history can shift a
-- little and the latest month may differ from the rating shown on Maps, which
-- Google rounds and computes itself.

WITH reviews AS (
    SELECT
        location_id,
        DATE_TRUNC(DATE(created_at), MONTH) AS month,
        star_rating,
        reply_comment IS NOT NULL           AS has_reply,
        TIMESTAMP_DIFF(reply_updated_at, created_at, HOUR) AS hours_to_reply
    FROM {{staging.google_my_business_profile.review}}
    WHERE created_at IS NOT NULL
),

spine AS (
    SELECT location_id, month
    FROM (
        SELECT location_id, MIN(month) AS first_month
        FROM reviews
        GROUP BY 1
    ),
    UNNEST(GENERATE_DATE_ARRAY(first_month, DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)) AS month
),

monthly AS (
    SELECT
        location_id,
        month,
        COUNT(*)                                   AS new_reviews,
        COUNT(star_rating)                         AS new_rated_reviews,
        SUM(star_rating)                           AS new_rating_sum,
        COUNTIF(star_rating <= 2)                  AS new_negative_reviews,
        COUNTIF(has_reply)                         AS new_reviews_replied,
        APPROX_QUANTILES(IF(has_reply, hours_to_reply, NULL), 2)[OFFSET(1)] AS median_hours_to_reply
    FROM reviews
    GROUP BY 1, 2
)

SELECT
    s.month,
    s.location_id,
    l.location_name,
    l.store_code,
    COALESCE(m.new_reviews, 0)                              AS new_reviews,
    COALESCE(m.new_negative_reviews, 0)                     AS new_negative_reviews,
    SAFE_DIVIDE(m.new_rating_sum, m.new_rated_reviews)      AS average_rating_new,
    SAFE_DIVIDE(m.new_reviews_replied, m.new_reviews)       AS reply_rate,
    m.median_hours_to_reply,
    SUM(COALESCE(m.new_reviews, 0)) OVER running            AS total_reviews,
    SAFE_DIVIDE(
        SUM(COALESCE(m.new_rating_sum, 0)) OVER running,
        SUM(COALESCE(m.new_rated_reviews, 0)) OVER running
    )                                                       AS average_rating_to_date
FROM spine s
LEFT JOIN monthly m USING (location_id, month)
LEFT JOIN {{staging.google_my_business_profile.location}} l USING (location_id)
WINDOW running AS (PARTITION BY s.location_id ORDER BY s.month
                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
