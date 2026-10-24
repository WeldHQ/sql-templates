-- core.sprout_social.message_volume_daily
-- Daily message volume per profile and message type: what came in, what went out,
-- how much of it went out through Sprout, and how much became a case. The basis of
-- Sprout's inbox and engagement volume reporting.
--
-- Grain: date_day (UTC) x customer_profile_id x post_type.
-- Depends on: staging.sprout_social.message, .profile
--
-- Counts only. The connector does not sync Sprout's analytics endpoints, so there
-- are no impressions, reach, engagements or follower counts here.

WITH daily AS (
    SELECT
        DATE(created_at)                                  AS date_day,
        customer_profile_id,
        network,
        post_category,
        post_type,
        COUNT(*)                                          AS messages,
        COUNTIF(NOT is_sent)                              AS received_messages,
        COUNTIF(is_sent)                                  AS sent_messages,
        COUNTIF(sent_by_user_id IS NOT NULL)              AS sent_from_sprout,
        COUNTIF(case_id IS NOT NULL)                      AS messages_in_cases,
        COUNT(DISTINCT IF(NOT is_sent, author_guid, NULL)) AS unique_authors
    FROM {{staging.sprout_social.message}}
    GROUP BY 1, 2, 3, 4, 5
)

SELECT
    d.date_day,
    p.customer_id,
    d.customer_profile_id,
    p.profile_name,
    COALESCE(d.network, p.network_type) AS network,
    d.post_category,
    d.post_type,
    d.messages,
    d.received_messages,
    d.sent_messages,
    d.sent_from_sprout,
    d.messages_in_cases,
    d.unique_authors
FROM daily d
-- profile is one row per customer_profile_id after staging, so this cannot fan out.
LEFT JOIN {{staging.sprout_social.profile}} p
    ON p.customer_profile_id = d.customer_profile_id
