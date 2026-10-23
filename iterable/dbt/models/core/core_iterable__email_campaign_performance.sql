-- core_iterable__email_campaign_performance
-- One row per email campaign with its whole-life numbers and rates: the headline table
-- in Iterable's Campaign Analytics for email.
--
-- Grain: one row per campaign (email campaigns, plus any campaign id that has email
-- sends). Sends without a campaign id are left out; they are in email_performance_daily.
-- Depends on: staging.iterable.email_send, .email_open, .email_click, .email_bounce,
--             .email_complaint, .email_unsubscribe, .campaigns
--
-- Every event is attributed to its campaign whenever it happened, so opens and clicks
-- that arrive days after the send still count for the campaign.
--
-- Unique counts are people, not messages: Iterable counts a unique open or click once per
-- user per campaign, keyed on email (or userId in userId projects). For a blast campaign
-- that is the same as one per message, but a triggered campaign can send one person many
-- messages, and counting messages would put unique opens above recipients. Email is used
-- here because it is on every email event in every project type.
--
-- Rates follow Iterable's definitions: delivered is sends minus bounces; unique open,
-- unique click, complaint and unsubscribe rates are over delivered; click-to-open is
-- unique clicks over unique opens. Each event table is aggregated per campaign before the
-- join, so nothing fans out.
--
-- Triggered campaigns (journeys, API sends) keep sending, so their numbers grow with
-- every sync. Compare them over a fixed window with email_performance_daily instead.

WITH sends AS (
    SELECT campaign_id, COUNT(*) AS sends, COUNT(DISTINCT email) AS recipients,
           MIN(event_at) AS first_send_at, MAX(event_at) AS last_send_at
    FROM {{ ref('stg_iterable__email_send') }}
    GROUP BY 1
),

bounces AS (
    SELECT campaign_id, COUNT(*) AS bounces
    FROM {{ ref('stg_iterable__email_bounce') }}
    GROUP BY 1
),

opens AS (
    SELECT campaign_id, COUNT(*) AS opens,
           COUNT(DISTINCT email) AS unique_opens
    FROM {{ ref('stg_iterable__email_open') }}
    GROUP BY 1
),

clicks AS (
    SELECT campaign_id, COUNT(*) AS clicks,
           COUNT(DISTINCT email) AS unique_clicks
    FROM {{ ref('stg_iterable__email_click') }}
    GROUP BY 1
),

complaints AS (
    SELECT campaign_id, COUNT(*) AS complaints
    FROM {{ ref('stg_iterable__email_complaint') }}
    GROUP BY 1
),

unsubscribes AS (
    SELECT campaign_id, COUNT(*) AS unsubscribes, COUNT(DISTINCT email) AS unique_unsubscribes
    FROM {{ ref('stg_iterable__email_unsubscribe') }}
    GROUP BY 1
),

campaign_ids AS (
    SELECT campaign_id FROM {{ ref('stg_iterable__campaigns') }} WHERE LOWER(message_medium) = 'email'
    UNION DISTINCT
    SELECT campaign_id FROM sends WHERE campaign_id IS NOT NULL
)

SELECT
    ids.campaign_id,
    c.campaign_name,
    c.campaign_type,
    c.campaign_state,
    c.created_at,
    s.first_send_at,
    s.last_send_at,

    COALESCE(s.sends, 0)                                            AS sends,
    COALESCE(s.recipients, 0)                                       AS recipients,
    COALESCE(b.bounces, 0)                                          AS bounces,
    COALESCE(s.sends, 0) - COALESCE(b.bounces, 0)                   AS delivered,
    COALESCE(o.opens, 0)                                            AS opens,
    COALESCE(o.unique_opens, 0)                                     AS unique_opens,
    COALESCE(k.clicks, 0)                                           AS clicks,
    COALESCE(k.unique_clicks, 0)                                    AS unique_clicks,
    COALESCE(cp.complaints, 0)                                      AS complaints,
    COALESCE(u.unsubscribes, 0)                                     AS unsubscribes,
    COALESCE(u.unique_unsubscribes, 0)                              AS unique_unsubscribes,

    SAFE_DIVIDE(COALESCE(s.sends, 0) - COALESCE(b.bounces, 0), s.sends)                       AS delivery_rate,
    SAFE_DIVIDE(o.unique_opens, COALESCE(s.sends, 0) - COALESCE(b.bounces, 0))                AS unique_open_rate,
    SAFE_DIVIDE(k.unique_clicks, COALESCE(s.sends, 0) - COALESCE(b.bounces, 0))               AS unique_click_rate,
    SAFE_DIVIDE(k.unique_clicks, o.unique_opens)                                              AS click_to_open_rate,
    SAFE_DIVIDE(cp.complaints, COALESCE(s.sends, 0) - COALESCE(b.bounces, 0))                 AS complaint_rate,
    SAFE_DIVIDE(u.unique_unsubscribes, COALESCE(s.sends, 0) - COALESCE(b.bounces, 0))         AS unsubscribe_rate
FROM campaign_ids ids
LEFT JOIN {{ ref('stg_iterable__campaigns') }} c ON c.campaign_id = ids.campaign_id
LEFT JOIN sends s          ON s.campaign_id = ids.campaign_id
LEFT JOIN bounces b        ON b.campaign_id = ids.campaign_id
LEFT JOIN opens o          ON o.campaign_id = ids.campaign_id
LEFT JOIN clicks k         ON k.campaign_id = ids.campaign_id
LEFT JOIN complaints cp    ON cp.campaign_id = ids.campaign_id
LEFT JOIN unsubscribes u   ON u.campaign_id = ids.campaign_id
