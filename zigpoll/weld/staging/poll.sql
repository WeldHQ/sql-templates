-- staging.zigpoll.poll
-- Thin wrapper over raw `poll`. One row per Zigpoll survey ("poll").
--
-- The counters (render_count, open_count, ...) are Zigpoll's lifetime totals as of
-- the last sync, not events, so they cannot be split by date.
--
-- `is_synthetic` marks polls that run on Zigpoll's synthetic (simulated) responses
-- rather than real visitors. Core drops them from every count.

SELECT
    'account_1'                              AS zigpoll_account,
    CAST(id AS STRING)                       AS poll_id,
    CAST(account_id AS STRING)               AS account_id,
    NULLIF(TRIM(CAST(title AS STRING)), '')  AS poll_title,
    CAST(status AS STRING)                   AS status,
    CAST(is_visible AS BOOL)                 AS is_visible,
    CAST(is_archived AS BOOL)                AS is_archived,
    COALESCE(CAST(is_synthetic AS BOOL), FALSE) AS is_synthetic,
    CAST(created_at AS TIMESTAMP)            AS created_at,
    CAST(render_count AS INT64)              AS render_count,
    CAST(presentation_count AS INT64)        AS presentation_count,
    CAST(open_count AS INT64)                AS open_count,
    CAST(engagement_count AS INT64)          AS engagement_count,
    CAST(complete_count AS INT64)            AS complete_count,
    CAST(close_count AS INT64)               AS close_count,
    CAST(participant_count AS INT64)         AS participant_count
FROM {{raw.zigpoll.poll}}
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
