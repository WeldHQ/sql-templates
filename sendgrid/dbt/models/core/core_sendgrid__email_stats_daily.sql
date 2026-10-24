-- core_sendgrid__email_stats_daily
-- SendGrid's global Stats overview, rebuilt: the delivery funnel and engagement for all
-- mail sent through the account, per day.
--
-- Grain: one row per day, as SendGrid's Stats API buckets it.
-- Depends on: staging.sendgrid.stat
--
-- The funnel, in SendGrid's terms:
--   requests   messages you asked SendGrid to send
--   processed  accepted for delivery (requests minus drops)
--   delivered  accepted by the receiving server
--   bounces, blocks, deferred   rejected permanently, rejected for reputation or policy,
--              or delayed and retried
--   *_drops    never attempted, because the address was already suppressed
--
-- Rates follow SendGrid's own definitions: delivery and bounce rates are over requests,
-- open, click, spam and unsubscribe rates are over delivered. They are per day. To report
-- a week or a month, sum the counts and divide again; averaging the daily rates weights a
-- quiet Sunday the same as a campaign day.
--
-- `unique_opens` and `unique_clicks` are unique per day as SendGrid reports them, so they
-- cannot be summed into a unique count over a longer window. Apple Mail Privacy
-- Protection pre-fetches images, which inflates opens; treat clicks as the firmer signal.

SELECT
    date,
    requests,
    processed,
    delivered,
    deferred,
    bounces,
    blocks,
    invalid_emails,
    bounce_drops,
    spam_report_drops,
    unsubscribe_drops,
    COALESCE(bounce_drops, 0) + COALESCE(spam_report_drops, 0)
        + COALESCE(unsubscribe_drops, 0)                        AS total_drops,
    opens,
    unique_opens,
    clicks,
    unique_clicks,
    spam_reports,
    unsubscribes,

    SAFE_DIVIDE(delivered, requests)                            AS delivery_rate,
    SAFE_DIVIDE(bounces, requests)                              AS bounce_rate,
    SAFE_DIVIDE(unique_opens, delivered)                        AS unique_open_rate,
    SAFE_DIVIDE(unique_clicks, delivered)                       AS unique_click_rate,
    SAFE_DIVIDE(unique_clicks, unique_opens)                    AS click_to_open_rate,
    SAFE_DIVIDE(spam_reports, delivered)                        AS spam_report_rate,
    SAFE_DIVIDE(unsubscribes, delivered)                        AS unsubscribe_rate
FROM {{ ref('stg_sendgrid__stat') }}
