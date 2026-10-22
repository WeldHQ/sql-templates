-- staging.sendgrid.stat
-- Thin wrapper over raw `stat`: SendGrid's global email statistics, one row per day.
-- Casts and de-duplicates. No other logic.
--
-- Grain: one row per date.
-- SendGrid restates recent days as late opens and clicks arrive, and the connector syncs
-- this stream incrementally, so a date can be delivered more than once. Only the most
-- recently synced copy of each date is kept.

SELECT
    CAST(date AS DATE)                      AS date,
    CAST(requests AS INT64)                 AS requests,
    CAST(processed AS INT64)                AS processed,
    CAST(delivered AS INT64)                AS delivered,
    CAST(deferred AS INT64)                 AS deferred,
    CAST(bounces AS INT64)                  AS bounces,
    CAST(blocks AS INT64)                   AS blocks,
    CAST(invalid_emails AS INT64)           AS invalid_emails,
    CAST(bounce_drops AS INT64)             AS bounce_drops,
    CAST(spam_report_drops AS INT64)        AS spam_report_drops,
    CAST(unsubscribe_drops AS INT64)        AS unsubscribe_drops,
    CAST(opens AS INT64)                    AS opens,
    CAST(unique_opens AS INT64)             AS unique_opens,
    CAST(clicks AS INT64)                   AS clicks,
    CAST(unique_clicks AS INT64)            AS unique_clicks,
    CAST(spam_reports AS INT64)             AS spam_reports,
    CAST(unsubscribes AS INT64)             AS unsubscribes
FROM {{raw.sendgrid.stat}}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY CAST(date AS DATE) ORDER BY _weld_synced DESC) = 1
