-- stg_salesforce__event
-- Thin wrapper over raw `event`. Casts, renames, drops deleted records.
-- Grain: one row per event.
--
-- Timed events carry activity_date_time (the start); all-day events carry only
-- activity_date. event_date takes whichever is set.
--
-- is_recurrence marks the series record of a Salesforce Classic recurring event.
-- Each occurrence is its own row, so core leaves the series record out to avoid
-- counting a meeting once more than it happened.

SELECT
    'org_1'                                        AS salesforce_org,
    CAST(id AS STRING)                             AS event_id,
    CAST(owner_id AS STRING)                       AS owner_id,
    CAST(what_id AS STRING)                        AS what_id,
    CAST(who_id AS STRING)                         AS who_id,
    CAST(account_id AS STRING)                     AS account_id,
    NULLIF(TRIM(CAST(subject AS STRING)), '')      AS subject,
    NULLIF(TRIM(CAST(type AS STRING)), '')         AS event_type,
    CAST(is_all_day_event AS BOOL)                 AS is_all_day_event,
    CAST(is_recurrence AS BOOL)                    AS is_recurrence,
    CAST(duration_in_minutes AS INT64)             AS duration_minutes,
    CAST(activity_date_time AS TIMESTAMP)          AS starts_at,
    COALESCE(
        DATE(CAST(activity_date_time AS TIMESTAMP)),
        DATE(CAST(activity_date AS TIMESTAMP))
    )                                              AS event_date,
    CAST(created_date AS TIMESTAMP)                AS created_at
FROM {{ source('salesforce', 'event') }}
WHERE NOT COALESCE(is_deleted, FALSE)
