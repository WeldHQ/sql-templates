-- core_sendgrid__mailbox_provider_stats_daily
-- SendGrid's Mailbox Provider stats, rebuilt: deliverability and engagement by the
-- receiving provider. This is where a reputation problem shows up first, usually as
-- blocks or deferrals at one provider while the others look normal.
--
-- Grain: one row per day x mailbox provider.
-- Depends on: staging.sendgrid.mailbox_provider_stat
--
-- SendGrid does not report requests per provider, so the denominator for delivery and
-- bounce rates here is attempted mail: delivered + bounces + blocks. Deferred mail is
-- retried and usually lands later as delivered or bounced, so it is not added again.
-- Engagement rates are over delivered, as in email_stats_daily.

SELECT
    date,
    mailbox_provider,
    delivered,
    deferred,
    bounces,
    blocks,
    drops,
    opens,
    unique_opens,
    clicks,
    unique_clicks,
    spam_reports,

    COALESCE(delivered, 0) + COALESCE(bounces, 0) + COALESCE(blocks, 0) AS attempted,
    SAFE_DIVIDE(delivered,
        COALESCE(delivered, 0) + COALESCE(bounces, 0) + COALESCE(blocks, 0)) AS delivery_rate,
    SAFE_DIVIDE(COALESCE(bounces, 0) + COALESCE(blocks, 0),
        COALESCE(delivered, 0) + COALESCE(bounces, 0) + COALESCE(blocks, 0)) AS rejection_rate,
    SAFE_DIVIDE(unique_opens, delivered)                        AS unique_open_rate,
    SAFE_DIVIDE(unique_clicks, delivered)                       AS unique_click_rate,
    SAFE_DIVIDE(spam_reports, delivered)                        AS spam_report_rate
FROM {{ ref('stg_sendgrid__mailbox_provider_stat') }}
