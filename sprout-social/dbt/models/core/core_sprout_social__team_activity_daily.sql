-- core_sprout_social__team_activity_daily
-- Messages each Sprout user sent from Sprout, per day and profile: the volume side
-- of Sprout's team report.
--
-- Grain: date_day (UTC) x sent_by_user_id x customer_profile_id.
-- Depends on: staging.sprout_social.message, .profile
--
-- Only messages sent from inside Sprout carry the sending user. Posts published
-- natively on the network count in message_volume_daily but not here. Response
-- times are not in the synced fields, so they are not computed.

SELECT
    DATE(m.created_at)                AS date_day,
    m.sent_by_user_id,
    ANY_VALUE(m.sent_by_user_name)    AS sent_by_user_name,
    p.customer_id,
    m.customer_profile_id,
    ANY_VALUE(p.profile_name)         AS profile_name,
    ANY_VALUE(m.network)              AS network,
    COUNT(*)                          AS messages_sent,
    COUNTIF(m.case_id IS NOT NULL)    AS messages_sent_in_cases,
    COUNT(DISTINCT m.post_type)       AS post_types_used
FROM {{ ref('stg_sprout_social__message') }} m
-- profile is one row per customer_profile_id after staging, so this cannot fan out.
LEFT JOIN {{ ref('stg_sprout_social__profile') }} p
    ON p.customer_profile_id = m.customer_profile_id
WHERE m.sent_by_user_id IS NOT NULL
GROUP BY date_day, m.sent_by_user_id, p.customer_id, m.customer_profile_id
