-- core_mailchimp__campaign_performance
-- Mailchimp's campaign report, one row per sent campaign: who it went to, how much was
-- delivered, opened and clicked, who unsubscribed, and attributed e-commerce revenue.
--
-- Grain: one row per campaign (sent campaigns only).
-- Depends on: staging.mailchimp.campaign, .campaign_setting, .campaign_recipient,
--             .campaign_report_summary, .campaign_member_recipient, .member_activity
--
-- Two kinds of numbers live side by side here, on purpose:
--   * Mailchimp's own: opens, unique_opens, open_rate, clicks, unique_clickers,
--     click_rate and the e-commerce columns, straight from the campaign report. These
--     match the Mailchimp UI.
--   * Rebuilt from the "sent to" list: recipients, hard and soft bounces, delivered.
--     Mailchimp's open and click rates are over delivered, which is why it is here:
--     unique_opens / delivered should land on open_rate.
--
-- `unsubscribes` comes from the member activity feed, which Mailchimp caps at the last
-- 50 events per member. It is a floor and can undercount for old campaigns sent to very
-- active members. An unsubscribe only counts for a campaign when the member is on that
-- campaign's sent-to list, so the numerator of `unsubscribe_rate` is always a subset of
-- its denominator. A member who unsubscribes twice from one campaign counts once.
--
-- The member-level aggregates are built per campaign before the join, so the joins are
-- one-to-one and nothing fans out.

WITH delivery AS (
    SELECT
        campaign_id,
        COUNT(*)                                            AS recipients,
        COUNTIF(delivery_status = 'hard')                   AS hard_bounces,
        COUNTIF(delivery_status = 'soft')                   AS soft_bounces,
        COUNTIF(open_count > 0)                             AS recipients_opened
    FROM {{ ref('stg_mailchimp__campaign_member_recipient') }}
    GROUP BY 1
),

unsubscribes AS (
    -- unsub events tied to a campaign, kept only for members that campaign was sent to
    SELECT
        a.campaign_id,
        COUNT(DISTINCT CONCAT(a.list_id, ':', a.member_id)) AS unsubscribes
    FROM {{ ref('stg_mailchimp__member_activity') }} a
    INNER JOIN {{ ref('stg_mailchimp__campaign_member_recipient') }} sent_to
        ON  sent_to.campaign_id = a.campaign_id
        AND sent_to.list_id = a.list_id
        AND sent_to.member_id = a.member_id
    WHERE a.action = 'unsub'
    GROUP BY 1
)

SELECT
    c.campaign_id,
    c.web_id,
    c.campaign_type,
    c.sent_at,
    DATE(c.sent_at)                                         AS sent_date,
    s.title,
    s.subject_line,
    s.from_name,
    r.list_id,
    r.list_name,
    r.segment_text,

    c.emails_sent,
    d.recipients,
    d.hard_bounces,
    d.soft_bounces,
    d.recipients - COALESCE(d.hard_bounces, 0) - COALESCE(d.soft_bounces, 0) AS delivered,

    rs.opens,
    rs.unique_opens,
    rs.open_rate,
    rs.clicks,
    rs.unique_clickers,
    rs.click_rate,
    SAFE_DIVIDE(rs.unique_clickers, rs.unique_opens)        AS click_to_open_rate,
    d.recipients_opened,

    COALESCE(u.unsubscribes, 0)                             AS unsubscribes,
    SAFE_DIVIDE(COALESCE(u.unsubscribes, 0),
        d.recipients - COALESCE(d.hard_bounces, 0) - COALESCE(d.soft_bounces, 0)) AS unsubscribe_rate,

    rs.ecommerce_orders,
    rs.ecommerce_revenue
FROM {{ ref('stg_mailchimp__campaign') }} c
LEFT JOIN {{ ref('stg_mailchimp__campaign_setting') }} s        ON s.campaign_id = c.campaign_id
LEFT JOIN {{ ref('stg_mailchimp__campaign_recipient') }} r      ON r.campaign_id = c.campaign_id
LEFT JOIN {{ ref('stg_mailchimp__campaign_report_summary') }} rs ON rs.campaign_id = c.campaign_id
LEFT JOIN delivery d                                      ON d.campaign_id = c.campaign_id
LEFT JOIN unsubscribes u                                  ON u.campaign_id = c.campaign_id
WHERE c.status = 'sent'
