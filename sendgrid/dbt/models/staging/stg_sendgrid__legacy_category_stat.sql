-- stg_sendgrid__legacy_category_stat
-- Thin wrapper over raw `legacy_category_stat`: SendGrid's email statistics per category,
-- one row per day per category. Casts, renames `name` to `category`, de-duplicates.
--
-- Grain: date x category.
-- Categories are the free-text labels you attach to messages when sending. The stream
-- carries a `legacy_` prefix only because the /categories endpoints sit with SendGrid's
-- legacy contact API; the statistics themselves are current.

SELECT
    CAST(date AS DATE)                      AS date,
    CAST(name AS STRING)                    AS category,
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
FROM {{ source('sendgrid', 'legacy_category_stat') }}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(date AS DATE), name
    ORDER BY _weld_synced DESC
) = 1
