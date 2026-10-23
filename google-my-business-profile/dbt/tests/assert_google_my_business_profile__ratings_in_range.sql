-- Star ratings are 1 to 5. Anything else means the enum mapping in staging missed
-- a value Google sends.

SELECT month, location_id, average_rating_new, average_rating_to_date
FROM {{ ref('core_google_my_business_profile__reviews_monthly') }}
WHERE average_rating_new NOT BETWEEN 1 AND 5
   OR average_rating_to_date NOT BETWEEN 1 AND 5
