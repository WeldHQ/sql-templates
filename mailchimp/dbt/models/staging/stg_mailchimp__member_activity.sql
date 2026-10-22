-- stg_mailchimp__member_activity
-- Thin wrapper over raw `member_activity`: per-member events (sent, open, click, bounce,
-- unsub and others) from Mailchimp's member activity feed. Casts, de-duplicates.
--
-- Grain: list_id x member_id x activity time x action.
-- Mailchimp's member activity endpoint returns the most recent 50 events per member, so
-- very active members lose their older events. Counts built from it are a floor, not an
-- exact figure. The stream is incremental, and an event can arrive in more than one sync.

SELECT
    CAST(list_id AS STRING)                 AS list_id,
    CAST(member_id AS STRING)               AS member_id,
    CAST(campaign_id AS STRING)             AS campaign_id,
    LOWER(CAST(action AS STRING))           AS action,
    CAST(timestamp AS TIMESTAMP)            AS activity_at,
    CAST(url AS STRING)                     AS url,
    CAST(type AS STRING)                    AS activity_type
FROM {{ source('mailchimp', 'member_activity') }}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY list_id, member_id, timestamp, action
    ORDER BY _weld_synced DESC
) = 1
