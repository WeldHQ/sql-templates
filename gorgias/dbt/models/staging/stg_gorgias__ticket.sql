-- stg_gorgias__ticket
-- Thin wrapper over raw `ticket`. Casts, renames, unpacks the team, keeps one row
-- per ticket. No business logic.
--
-- Tickets arrive both from the ticket list and from merge events, so the same
-- ticket can arrive more than once; the latest version wins here. A
-- ticket merged into another can arrive as little more than its id and the merge
-- fields, which is why core drops merged tickets rather than counting them.
--
-- The assignee user is flattened into assignee_user_* columns. The team is a
-- JSON object and is unpacked here.
--
-- reporting_timezone: Gorgias reports in the account's time zone and the
-- connector does not sync account settings, so set the IANA name here.
-- Timestamps are UTC.
--
-- Single Gorgias account. To add another, UNION ALL a second block below with a
-- different gorgias_account label. Ticket IDs are only unique within one account.

SELECT
    'account_1'                                        AS gorgias_account,
    'UTC'                                              AS reporting_timezone,
    CAST(id AS STRING)                                 AS ticket_id,
    CAST(created_datetime AS TIMESTAMP)                AS created_at,
    CAST(opened_datetime AS TIMESTAMP)                 AS opened_at,
    CAST(closed_datetime AS TIMESTAMP)                 AS closed_at,
    CAST(updated_datetime AS TIMESTAMP)                AS updated_at,
    CAST(trashed_datetime AS TIMESTAMP)                AS trashed_at,
    CAST(snooze_datetime AS TIMESTAMP)                 AS snoozed_until,
    CAST(last_message_datetime AS TIMESTAMP)           AS last_message_at,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))    AS status,
    LOWER(NULLIF(TRIM(CAST(priority AS STRING)), ''))  AS priority,
    LOWER(NULLIF(TRIM(CAST(channel AS STRING)), ''))   AS channel,
    LOWER(NULLIF(TRIM(CAST(via AS STRING)), ''))       AS via,
    NULLIF(TRIM(CAST(subject AS STRING)), '')          AS subject,
    NULLIF(TRIM(CAST(language AS STRING)), '')         AS language,
    CAST(from_agent AS BOOL)                           AS is_from_agent,
    CAST(messages_count AS INT64)                      AS messages_count,
    CAST(customer_id AS STRING)                        AS customer_id,
    CAST(assignee_user_id AS STRING)                   AS assignee_id,
    NULLIF(TRIM(CAST(assignee_user_name AS STRING)), '') AS assignee_name,
    LOWER(NULLIF(TRIM(CAST(assignee_user_email AS STRING)), '')) AS assignee_email,
    JSON_VALUE(assignee_team, '$.id')                  AS team_id,
    JSON_VALUE(assignee_team, '$.name')                AS team_name,
    COALESCE(CAST(spam AS BOOL), FALSE)                AS is_spam,
    -- Merged is read across every copy of the ticket: the merge-event row and
    -- the ticket-list row can disagree, and once merged a ticket stays merged.
    COALESCE(LOGICAL_OR(CAST(merged AS BOOL)) OVER (PARTITION BY id), FALSE) AS is_merged,
    MAX(CAST(merged_into AS STRING)) OVER (PARTITION BY id)                  AS merged_into_ticket_id
FROM {{ source('gorgias', 'ticket') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY id
    -- A merge-event row can lack updated_datetime; prefer the newest full row.
    ORDER BY updated_datetime DESC NULLS LAST
) = 1
