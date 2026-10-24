-- core_google_my_business_profile__search_keywords_monthly
-- The search terms people used to find each location on Google Search and Maps,
-- per month, ranked. The "Searches" panel of the Performance view.
--
-- Grain: month x location_id x search_keyword.
-- Depends on: staging.google_my_business_profile.search_keyword_impressions, .location
--
-- Google hides small counts behind a threshold. For those rows `impressions` is
-- NULL, `is_below_threshold` is TRUE and `impressions_upper_bound` is the
-- threshold. Sum `impressions` for a floor and `impressions_upper_bound` for a
-- ceiling; there is no exact total. Keyword impressions are counted per month, not
-- per day, so they do not add up to the daily impressions.

SELECT
    k.month,
    k.location_id,
    l.location_name,
    k.search_keyword,
    k.impressions,
    k.impressions IS NULL                                  AS is_below_threshold,
    COALESCE(k.impressions, k.impressions_threshold)       AS impressions_upper_bound,
    RANK() OVER (
        PARTITION BY k.month, k.location_id
        ORDER BY COALESCE(k.impressions, 0) DESC
    )                                                      AS keyword_rank
FROM {{ ref('stg_google_my_business_profile__search_keyword_impressions') }} k
LEFT JOIN {{ ref('stg_google_my_business_profile__location') }} l USING (location_id)
