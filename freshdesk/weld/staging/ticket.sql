-- staging.freshdesk.ticket
-- Thin wrapper over raw `ticket`. Casts, renames, decodes Freshdesk's integer
-- codes, keeps one row per ticket. No business logic.
--
-- Freshdesk stores status, priority and source as integers. The documented
-- values are decoded here so core never repeats the mapping:
--   status    2 Open, 3 Pending, 4 Resolved, 5 Closed (6 and up are custom statuses)
--   priority  1 Low, 2 Medium, 3 High, 4 Urgent
--   source    1 Email, 2 Portal, 3 Phone, 7 Chat, 9 Feedback widget, 10 Outbound email
-- Anything else is kept as e.g. `status_7`, so a custom status shows up by
-- number instead of silently becoming NULL. Put your custom status names in the
-- CASE if you use them.
--
-- WHAT IS NOT HERE: the connector does not sync Freshdesk's ticket stats, so
-- there is no resolved_at, closed_at or first_responded_at. First response is
-- derived from conversations in core; resolution time cannot be built at all.
--
-- reporting_timezone: Freshdesk reports in the helpdesk's time zone. The synced
-- `account` table stores it as a display name ("Eastern Time (US & Canada)")
-- that BigQuery cannot parse, so set the IANA name here. Timestamps are UTC.
--
-- Single helpdesk. To add another, UNION ALL a second block below pointing at
-- that helpdesk's connector with a different freshdesk_account label. Ticket IDs
-- are only unique within one helpdesk.

SELECT
    'account_1'                                       AS freshdesk_account,
    'UTC'                                             AS reporting_timezone,
    CAST(id AS STRING)                                AS ticket_id,
    CAST(created_at AS TIMESTAMP)                     AS created_at,
    CAST(updated_at AS TIMESTAMP)                     AS updated_at,
    CAST(status AS INT64)                             AS status_code,
    CASE CAST(status AS INT64)
        WHEN 2 THEN 'Open'
        WHEN 3 THEN 'Pending'
        WHEN 4 THEN 'Resolved'
        WHEN 5 THEN 'Closed'
        ELSE CONCAT('status_', CAST(status AS STRING))
    END                                               AS status,
    CASE CAST(priority AS INT64)
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Urgent'
        ELSE CONCAT('priority_', CAST(priority AS STRING))
    END                                               AS priority,
    CAST(source AS INT64)                             AS source_code,
    CASE CAST(source AS INT64)
        WHEN 1 THEN 'Email'
        WHEN 2 THEN 'Portal'
        WHEN 3 THEN 'Phone'
        WHEN 7 THEN 'Chat'
        WHEN 9 THEN 'Feedback widget'
        WHEN 10 THEN 'Outbound email'
        ELSE CONCAT('source_', CAST(source AS STRING))
    END                                               AS channel,
    NULLIF(TRIM(CAST(type AS STRING)), '')            AS ticket_type,
    NULLIF(TRIM(CAST(subject AS STRING)), '')         AS subject,
    CAST(group_id AS STRING)                          AS group_id,
    CAST(responder_id AS STRING)                      AS responder_id,
    CAST(requester_id AS STRING)                      AS requester_id,
    CAST(company_id AS STRING)                        AS company_id,
    CAST(product_id AS STRING)                        AS product_id,
    COALESCE(CAST(spam AS BOOL), FALSE)               AS is_spam,
    CAST(fr_due_by AS TIMESTAMP)                      AS first_response_due_at,
    CAST(due_by AS TIMESTAMP)                         AS resolution_due_at,
    CAST(fr_escalated AS BOOL)                        AS is_first_response_escalated,
    CAST(is_escalated AS BOOL)                        AS is_resolution_escalated
FROM {{raw.freshdesk.ticket}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
