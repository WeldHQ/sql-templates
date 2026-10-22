-- staging.mailchimp.member
-- Thin wrapper over raw `member`: one row per contact per audience, current state.
-- Casts, renames, de-duplicates.
--
-- Grain: list_id x member_id.
-- Mailchimp's member id is a hash of the lower-cased email address, so the same person on
-- two audiences has the same id twice. Every key here includes list_id for that reason.
-- The stream is incremental on `last_changed`, so a member can arrive more than once; the
-- latest version is kept.
-- `status` is subscribed, unsubscribed, cleaned, pending, transactional or archived.

SELECT
    CAST(list_id AS STRING)                 AS list_id,
    CAST(id AS STRING)                      AS member_id,
    LOWER(CAST(email_address AS STRING))    AS email_address,
    LOWER(CAST(status AS STRING))           AS status,
    CAST(source AS STRING)                  AS source,
    CAST(member_rating AS INT64)            AS member_rating,
    CAST(timestamp_signup AS TIMESTAMP)     AS signed_up_at,
    CAST(timestamp_opt AS TIMESTAMP)        AS opted_in_at,
    CAST(last_changed AS TIMESTAMP)         AS last_changed_at,
    CAST(stats_avg_open_rate AS FLOAT64)    AS avg_open_rate,
    CAST(stats_avg_click_rate AS FLOAT64)   AS avg_click_rate,
    CAST(vip AS BOOL)                       AS is_vip
FROM {{raw.mailchimp.member}}
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY list_id, id
    ORDER BY last_changed DESC, _weld_synced DESC
) = 1
