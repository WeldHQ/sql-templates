-- stg_google_my_business_profile__search_keyword_impressions
-- Thin wrapper over raw `location_search_keywords_impressions_monthly`. Casts and
-- renames. No other logic.
--
-- Grain: location x month x search keyword.
-- Google reports small counts only as "below a threshold": then `impressions` is
-- NULL and `impressions_threshold` holds the upper bound. Both are kept; do not
-- treat the threshold as a count.

SELECT
    CAST(location_id AS STRING)                            AS location_id,
    SAFE.PARSE_DATE('%Y-%m', CAST(month AS STRING))        AS month,
    LOWER(TRIM(CAST(search_keyword AS STRING)))            AS search_keyword,
    CAST(value AS INT64)                                   AS impressions,
    CAST(threshold AS INT64)                               AS impressions_threshold
FROM {{ source('google_my_business_profile', 'location_search_keywords_impressions_monthly') }}
