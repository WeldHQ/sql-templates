-- core.iterable.email_performance_daily
-- Email sends, opens, clicks, bounces, complaints and unsubscribes per campaign per day:
-- the email metrics in Iterable's Campaign Analytics, as a daily series.
--
-- Grain: one row per day (UTC, event time) x campaign.
-- Depends on: staging.iterable.email_send, .email_open, .email_click, .email_bounce,
--             .email_complaint, .email_unsubscribe, .campaigns
--
-- Each event is counted on the day it happened, so an email sent on Monday and opened on
-- Tuesday adds a send to Monday and an open to Tuesday. That is the right view for "what
-- happened this week". For "how did this campaign do", use email_campaign_performance,
-- which is not split by day.
--
-- `unique_opens` and `unique_clicks` count distinct messages (one send to one person)
-- that were opened or clicked that day, the way Iterable counts uniques. They are unique
-- per day and cannot be summed into unique counts over a longer window.
-- Events with no campaign id (some transactional API sends) are grouped under a NULL
-- campaign rather than dropped.

WITH events AS (
    SELECT 'send' AS event_type, campaign_id, message_id, email, event_at FROM {{staging.iterable.email_send}}
    UNION ALL
    SELECT 'open', campaign_id, message_id, email, event_at FROM {{staging.iterable.email_open}}
    UNION ALL
    SELECT 'click', campaign_id, message_id, email, event_at FROM {{staging.iterable.email_click}}
    UNION ALL
    SELECT 'bounce', campaign_id, message_id, email, event_at FROM {{staging.iterable.email_bounce}}
    UNION ALL
    SELECT 'complaint', campaign_id, message_id, email, event_at FROM {{staging.iterable.email_complaint}}
    UNION ALL
    SELECT 'unsubscribe', campaign_id, message_id, email, event_at FROM {{staging.iterable.email_unsubscribe}}
),

daily AS (
    SELECT
        DATE(event_at)                                                          AS date,
        campaign_id,
        COUNTIF(event_type = 'send')                                            AS sends,
        COUNTIF(event_type = 'bounce')                                          AS bounces,
        COUNTIF(event_type = 'open')                                            AS opens,
        COUNT(DISTINCT IF(event_type = 'open', COALESCE(message_id, email), NULL))  AS unique_opens,
        COUNTIF(event_type = 'click')                                           AS clicks,
        COUNT(DISTINCT IF(event_type = 'click', COALESCE(message_id, email), NULL)) AS unique_clicks,
        COUNTIF(event_type = 'complaint')                                       AS complaints,
        COUNTIF(event_type = 'unsubscribe')                                     AS unsubscribes
    FROM events
    WHERE event_at IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    d.date,
    d.campaign_id,
    c.campaign_name,
    c.campaign_type,
    d.sends,
    d.bounces,
    d.opens,
    d.unique_opens,
    d.clicks,
    d.unique_clicks,
    d.complaints,
    d.unsubscribes
FROM daily d
LEFT JOIN {{staging.iterable.campaigns}} c ON c.campaign_id = d.campaign_id
