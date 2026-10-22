-- core_google_my_business_profile__location_performance_daily
-- The Business Profile Performance view per location per day: how often the
-- profile was shown, on which surface, and what people did with it.
--
-- Grain: date_day x location_id.
-- Depends on: staging.google_my_business_profile.location_performance, .location
--
-- Impressions are unique users per day per surface, as Google defines them, so
-- the four surface columns can be added for a day but a "unique viewers this
-- month" figure cannot be built by summing days.
--
-- interactions follows Google's "Profile interactions": calls, messages,
-- bookings, directions, website clicks, food orders and menu clicks.

WITH pivoted AS (
    SELECT
        date_day,
        location_id,
        SUM(IF(metric = 'BUSINESS_IMPRESSIONS_DESKTOP_MAPS',   value, 0)) AS impressions_desktop_maps,
        SUM(IF(metric = 'BUSINESS_IMPRESSIONS_DESKTOP_SEARCH', value, 0)) AS impressions_desktop_search,
        SUM(IF(metric = 'BUSINESS_IMPRESSIONS_MOBILE_MAPS',    value, 0)) AS impressions_mobile_maps,
        SUM(IF(metric = 'BUSINESS_IMPRESSIONS_MOBILE_SEARCH',  value, 0)) AS impressions_mobile_search,
        SUM(IF(metric = 'CALL_CLICKS',                         value, 0)) AS calls,
        SUM(IF(metric = 'BUSINESS_DIRECTION_REQUESTS',         value, 0)) AS direction_requests,
        SUM(IF(metric = 'WEBSITE_CLICKS',                      value, 0)) AS website_clicks,
        SUM(IF(metric = 'BUSINESS_CONVERSATIONS',              value, 0)) AS conversations,
        SUM(IF(metric = 'BUSINESS_BOOKINGS',                   value, 0)) AS bookings,
        SUM(IF(metric = 'BUSINESS_FOOD_ORDERS',                value, 0)) AS food_orders,
        SUM(IF(metric = 'BUSINESS_FOOD_MENU_CLICKS',           value, 0)) AS food_menu_clicks
    FROM {{ ref('stg_google_my_business_profile__location_performance') }}
    GROUP BY 1, 2
)

SELECT
    p.date_day,
    p.location_id,
    l.location_name,
    l.store_code,
    l.locality,
    l.primary_category,

    p.impressions_desktop_maps + p.impressions_desktop_search
      + p.impressions_mobile_maps + p.impressions_mobile_search AS impressions,
    p.impressions_desktop_maps + p.impressions_mobile_maps       AS impressions_maps,
    p.impressions_desktop_search + p.impressions_mobile_search   AS impressions_search,
    p.impressions_desktop_maps,
    p.impressions_desktop_search,
    p.impressions_mobile_maps,
    p.impressions_mobile_search,

    p.calls + p.direction_requests + p.website_clicks + p.conversations
      + p.bookings + p.food_orders + p.food_menu_clicks          AS interactions,
    p.calls,
    p.direction_requests,
    p.website_clicks,
    p.conversations,
    p.bookings,
    p.food_orders,
    p.food_menu_clicks
FROM pivoted p
-- One row per location after staging, so this cannot fan out.
LEFT JOIN {{ ref('stg_google_my_business_profile__location') }} l USING (location_id)
