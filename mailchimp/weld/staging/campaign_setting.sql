-- staging.mailchimp.campaign_setting
-- Thin wrapper over raw `campaign_setting`: the subject line, title and sender of each
-- campaign. Casts and renames.
--
-- Grain: campaign_id.

SELECT
    CAST(campaign_id AS STRING)             AS campaign_id,
    CAST(title AS STRING)                   AS title,
    CAST(subject_line AS STRING)            AS subject_line,
    CAST(preview_text AS STRING)            AS preview_text,
    CAST(from_name AS STRING)               AS from_name,
    CAST(reply_to AS STRING)                AS reply_to,
    CAST(template_id AS STRING)             AS template_id
FROM {{raw.mailchimp.campaign_setting}}
