-- staging.mailchimp.campaign_member_recipient
-- Thin wrapper over raw `campaign_member_recipient`: Mailchimp's "sent to" report, one row
-- per member a campaign was sent to, with the delivery outcome. Casts and renames.
--
-- Grain: campaign_id x member_id.
-- `status` is `sent`, `hard` (hard bounce) or `soft` (soft bounce).

SELECT
    CAST(campaign_id AS STRING)             AS campaign_id,
    CAST(list_id AS STRING)                 AS list_id,
    CAST(member_id AS STRING)               AS member_id,
    LOWER(CAST(status AS STRING))           AS delivery_status,
    CAST(open_count AS INT64)               AS open_count,
    CAST(last_open AS TIMESTAMP)            AS last_opened_at,
    CAST(absplit_group AS STRING)           AS absplit_group
FROM {{raw.mailchimp.campaign_member_recipient}}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY campaign_id, member_id
    ORDER BY _weld_synced DESC
) = 1
