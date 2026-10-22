-- stg_mailchimp__campaign
-- Thin wrapper over raw `campaign`: one row per Mailchimp campaign. Casts and renames.
--
-- Grain: campaign_id.
-- `type` is regular, plaintext, absplit, rss or variate. `status` is save, paused,
-- schedule, sending or sent. Synced in full on every run, so no de-duplication is needed.

SELECT
    CAST(id AS STRING)                      AS campaign_id,
    CAST(web_id AS STRING)                  AS web_id,
    CAST(parent_campaign_id AS STRING)      AS parent_campaign_id,
    LOWER(CAST(type AS STRING))             AS campaign_type,
    LOWER(CAST(status AS STRING))           AS status,
    CAST(create_time AS TIMESTAMP)          AS created_at,
    CAST(send_time AS TIMESTAMP)            AS sent_at,
    CAST(emails_sent AS INT64)              AS emails_sent,
    CAST(archive_url AS STRING)             AS archive_url
FROM {{ source('mailchimp', 'campaign') }}
