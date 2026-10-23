-- The running review count at the latest month must equal the number of reviews
-- in staging, per location. A gap means reviews fell outside the month spine.

WITH latest AS (
    SELECT location_id, total_reviews
    FROM {{ ref('core_google_my_business_profile__reviews_monthly') }}
    WHERE month = DATE_TRUNC(CURRENT_DATE(), MONTH)
),

staged AS (
    SELECT location_id, COUNT(*) AS reviews
    FROM {{ ref('stg_google_my_business_profile__review') }}
    WHERE created_at IS NOT NULL
    GROUP BY 1
)

SELECT s.location_id, s.reviews, l.total_reviews
FROM staged s
LEFT JOIN latest l USING (location_id)
WHERE l.total_reviews IS NULL OR l.total_reviews != s.reviews
