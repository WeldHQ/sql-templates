-- stg_mailchimp__list_activity
-- Thin wrapper over raw `list_activity`: Mailchimp's daily audience activity (sends,
-- opens, clicks, bounces, subscribes, unsubscribes) per audience. Casts, de-duplicates.
--
-- Grain: list_id x day.
-- Mailchimp serves the last 180 days of this endpoint and keeps restating recent days, so
-- the stream is incremental on `day` and a day can arrive more than once. Only the latest
-- synced copy is kept. History older than 180 days exists only if the connector was
-- already syncing at the time.

SELECT
    CAST(list_id AS STRING)                 AS list_id,
    CAST(day AS DATE)                       AS day,
    CAST(emails_sent AS INT64)              AS emails_sent,
    CAST(unique_opens AS INT64)             AS unique_opens,
    CAST(recipient_clicks AS INT64)         AS recipient_clicks,
    CAST(hard_bounce AS INT64)              AS hard_bounces,
    CAST(soft_bounce AS INT64)              AS soft_bounces,
    CAST(subs AS INT64)                     AS subscribes,
    CAST(unsubs AS INT64)                   AS unsubscribes,
    CAST(other_adds AS INT64)               AS other_adds,
    CAST(other_removes AS INT64)            AS other_removes
FROM {{ source('mailchimp', 'list_activity') }}
WHERE day IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY list_id, CAST(day AS DATE)
    ORDER BY _weld_synced DESC
) = 1
