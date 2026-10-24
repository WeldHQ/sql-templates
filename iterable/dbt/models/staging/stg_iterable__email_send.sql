-- stg_iterable__email_send
-- Thin wrapper over raw `email_send`: one row per Iterable event, a send of an email
-- campaign to one recipient.
-- Casts and renames. No other logic.
--
-- Grain: one event.
-- Iterable's export fields arrive snake_cased (campaignId becomes campaign_id). Their
-- types are inferred from your data, so `created_at` is parsed whichever way it landed:
-- as a timestamp, as Iterable's "2026-01-31 12:00:00 +00:00" text, or as epoch
-- milliseconds. The stream is re-read in full on every sync, so rows do not repeat.

SELECT
    CAST(campaign_id AS STRING)             AS campaign_id,
    CAST(template_id AS STRING)             AS template_id,
    CAST(message_id AS STRING)              AS message_id,
    LOWER(CAST(email AS STRING))            AS email,
    COALESCE(
        SAFE_CAST(CAST(created_at AS STRING) AS TIMESTAMP),
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S %Ez', CAST(created_at AS STRING)),
        TIMESTAMP_MILLIS(SAFE_CAST(CAST(created_at AS STRING) AS INT64))
    ) AS event_at
FROM {{ source('iterable', 'email_send') }}
