-- stg_mailchimp__campaign_recipient
-- Thin wrapper over raw `campaign_recipient`: which audience (list) and segment each
-- campaign was sent to. Casts and renames.
--
-- Grain: campaign_id.

SELECT
    CAST(campaign_id AS STRING)             AS campaign_id,
    CAST(list_id AS STRING)                 AS list_id,
    CAST(list_name AS STRING)               AS list_name,
    CAST(segment_text AS STRING)            AS segment_text,
    CAST(recipient_count AS INT64)          AS recipient_count
FROM {{ source('mailchimp', 'campaign_recipient') }}
