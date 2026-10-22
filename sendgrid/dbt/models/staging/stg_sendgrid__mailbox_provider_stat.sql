-- stg_sendgrid__mailbox_provider_stat
-- Thin wrapper over raw `mailbox_provider_stat`: SendGrid's email statistics per receiving
-- mailbox provider (Gmail, Microsoft Outlook Live, Yahoo and so on). Casts, renames `name`
-- to `mailbox_provider`, de-duplicates.
--
-- Grain: date x mailbox provider.
-- This endpoint reports `drops` as one number rather than split by cause, and has no
-- `requests` or `processed` column.

SELECT
    CAST(date AS DATE)                      AS date,
    CAST(name AS STRING)                    AS mailbox_provider,
    CAST(delivered AS INT64)                AS delivered,
    CAST(deferred AS INT64)                 AS deferred,
    CAST(bounces AS INT64)                  AS bounces,
    CAST(blocks AS INT64)                   AS blocks,
    CAST(drops AS INT64)                    AS drops,
    CAST(opens AS INT64)                    AS opens,
    CAST(unique_opens AS INT64)             AS unique_opens,
    CAST(clicks AS INT64)                   AS clicks,
    CAST(unique_clicks AS INT64)            AS unique_clicks,
    CAST(spam_reports AS INT64)             AS spam_reports
FROM {{ source('sendgrid', 'mailbox_provider_stat') }}
WHERE date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY CAST(date AS DATE), name
    ORDER BY _weld_synced DESC
) = 1
