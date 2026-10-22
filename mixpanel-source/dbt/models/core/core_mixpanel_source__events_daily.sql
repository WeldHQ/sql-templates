-- core_mixpanel_source__events_daily
-- Mixpanel's Insights "Total events" and "Unique users" per event, per day.
--
-- Grain: one row per day (UTC) x event name.
-- Depends on: staging.mixpanel_source.events
--
-- `unique_users` counts distinct `distinct_id` values within the row. They are unique per
-- day and per event, so they cannot be summed across days or events into unique people;
-- use active_users_daily for that.
--
-- Mixpanel's UI resolves identities (an anonymous device and the user it later logged in
-- as are one person) and shows days in your project time zone. These counts use the raw
-- `distinct_id` and UTC days, so uniques can run slightly above Mixpanel's and days can
-- shift at the edges.

SELECT
    DATE(event_at)                          AS date,
    event_name,
    COUNT(*)                                AS events,
    COUNT(DISTINCT distinct_id)             AS unique_users,
    SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT distinct_id)) AS events_per_user
FROM {{ ref('stg_mixpanel_source__events') }}
GROUP BY 1, 2
