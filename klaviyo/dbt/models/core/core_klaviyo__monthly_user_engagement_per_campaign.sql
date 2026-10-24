-- core_klaviyo__monthly_user_engagement_per_campaign
-- Monthly User Engagement per Campaign. Calculates the monthly user engagement per
-- campaign using data from Klaviyo integration. It extracts the year, month,
-- campaign ID, event name, and counts the number of unique persons for specific
-- events. It then aggregates the counts for each event type and campaign, grouping
-- them by year, month, campaign ID, and campaign name. The final result is ordered
-- by year, month, and campaign name.
--
-- The event name comes from the metric table and persons are counted by Klaviyo
-- profile id. Events are tied to a campaign through Klaviyo's attribution data
-- (the event's campaign_id).
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Klaviyo; check the output against the source before relying
-- on it.

WITH MonthlyUniquePersonsPerEvent AS (
    SELECT
        EXTRACT(YEAR FROM e.timestamp) AS event_year,
        EXTRACT(MONTH FROM e.timestamp) AS event_month,
        e.campaign_id,
        m.name AS event_name,
        COUNT(DISTINCT e.profile_id) AS unique_persons
    FROM
        {{ source('klaviyo', 'event') }} e
    JOIN
        {{ source('klaviyo', 'metric') }} m ON m.id = e.metric_id
    WHERE
        m.name IN ('Dropped Email', 'Bounced Email', 'Received Email', 'Unsubscribed', 'Clicked Email', 'Opened Email')
        AND e.campaign_id IS NOT NULL
    GROUP BY
        event_year, event_month, event_name, e.campaign_id
)

SELECT
    mupe.event_year,
    mupe.event_month,
    c.id AS campaign_id,
    c.name AS campaign_name,
    SUM(CASE WHEN mupe.event_name = 'Dropped Email' THEN unique_persons ELSE 0 END) AS dropped_email_count,
    SUM(CASE WHEN mupe.event_name = 'Bounced Email' THEN unique_persons ELSE 0 END) AS bounced_email_count,
    SUM(CASE WHEN mupe.event_name = 'Received Email' THEN unique_persons ELSE 0 END) AS received_email_count,
    SUM(CASE WHEN mupe.event_name = 'Unsubscribed' THEN unique_persons ELSE 0 END) AS unsubscribed_count,
    SUM(CASE WHEN mupe.event_name = 'Clicked Email' THEN unique_persons ELSE 0 END) AS clicked_email_count,
    SUM(CASE WHEN mupe.event_name = 'Opened Email' THEN unique_persons ELSE 0 END) AS opened_email_count
FROM
    MonthlyUniquePersonsPerEvent mupe
JOIN
    {{ source('klaviyo', 'campaign') }} c ON mupe.campaign_id = c.id
GROUP BY
    mupe.event_year, mupe.event_month, c.id, c.name
ORDER BY
    mupe.event_year DESC, mupe.event_month DESC, c.name
