-- staging.iterable.campaigns
-- Thin wrapper over raw `campaigns`: one row per Iterable campaign, any channel. Casts
-- and renames.
--
-- Grain: campaign_id.
-- `message_medium` is Email, Push, InApp, SMS or WebPush. `campaign_type` is Blast
-- (one-off sends) or Triggered (journeys and API-triggered sends). Field types are
-- inferred from your data, so timestamps are parsed whichever way they landed.

SELECT
    CAST(id AS STRING)                      AS campaign_id,
    CAST(name AS STRING)                    AS campaign_name,
    CAST(type AS STRING)                    AS campaign_type,
    CAST(message_medium AS STRING)          AS message_medium,
    CAST(campaign_state AS STRING)          AS campaign_state,
    CAST(template_id AS STRING)             AS template_id,
    COALESCE(
        SAFE_CAST(CAST(created_at AS STRING) AS TIMESTAMP),
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%E*S %Ez', CAST(created_at AS STRING)),
        TIMESTAMP_MILLIS(SAFE_CAST(CAST(created_at AS STRING) AS INT64))
    ) AS created_at
FROM {{raw.iterable.campaigns}}
