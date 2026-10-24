-- core_sendgrid__category_stats_daily
-- SendGrid's Category Stats, rebuilt: the same funnel as email_stats_daily, split by the
-- category labels you attach when sending (for example "welcome", "receipt",
-- "newsletter-2026-10").
--
-- Grain: one row per day x category.
-- Depends on: staging.sendgrid.legacy_category_stat
--
-- Categories do not add up to the account total. A message can carry several categories
-- and is counted under each one, and a message with none is in no row here. Use
-- email_stats_daily for account totals.
--
-- Rates are per row, with the same definitions as email_stats_daily. Re-derive them from
-- summed counts when you aggregate.

SELECT
    date,
    category,
    requests,
    processed,
    delivered,
    deferred,
    bounces,
    blocks,
    invalid_emails,
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
    SAFE_DIVIDE(spam_reports, delivered)                        AS spam_report_rate,
    SAFE_DIVIDE(unsubscribes, delivered)                        AS unsubscribe_rate
FROM {{ ref('stg_sendgrid__legacy_category_stat') }}
