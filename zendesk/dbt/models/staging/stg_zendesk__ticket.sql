-- stg_zendesk__ticket
-- Thin wrapper over raw `ticket`. Casts, renames, unpacks two JSON columns, and
-- keeps one row per ticket. No business logic.
--
-- The connector reads Zendesk's incremental ticket export, which Zendesk itself
-- documents as able to return the same ticket more than once. The latest version
-- of each ticket wins here, so a repeated row can never double a count in core.
--
-- `via` and `satisfaction_rating` arrive as JSON strings. Only the parts the
-- reports need are pulled out: the channel the ticket came in on, and the CSAT
-- score (`good`, `bad`, `offered`, `unoffered`) with its reason. The rating
-- object carries no timestamp, which is why core dates CSAT on the solve date.
--
-- reporting_timezone: Zendesk reports in the account's own time zone and the
-- connector does not sync the account settings, so set it here. Timestamps are
-- UTC; every date in core is derived with this zone. Use an IANA name such as
-- 'Europe/Copenhagen'.
--
-- Single Zendesk account. To add another, UNION ALL a second block below pointing
-- at that account's connector with a different zendesk_account label. Ticket IDs
-- are only unique within one account.

SELECT
    'account_1'                                          AS zendesk_account,
    'UTC'                                                AS reporting_timezone,
    CAST(id AS STRING)                                   AS ticket_id,
    CAST(created_at AS TIMESTAMP)                        AS created_at,
    CAST(updated_at AS TIMESTAMP)                        AS updated_at,
    LOWER(NULLIF(TRIM(CAST(status AS STRING)), ''))      AS status,
    LOWER(NULLIF(TRIM(CAST(priority AS STRING)), ''))    AS priority,
    LOWER(NULLIF(TRIM(CAST(type AS STRING)), ''))        AS ticket_type,
    NULLIF(TRIM(CAST(subject AS STRING)), '')            AS subject,
    LOWER(JSON_VALUE(via, '$.channel'))                  AS channel,
    CAST(group_id AS STRING)                             AS group_id,
    CAST(assignee_id AS STRING)                          AS assignee_id,
    CAST(requester_id AS STRING)                         AS requester_id,
    CAST(organization_id AS STRING)                      AS organization_id,
    CAST(brand_id AS STRING)                             AS brand_id,
    LOWER(JSON_VALUE(satisfaction_rating, '$.score'))    AS satisfaction_score,
    JSON_VALUE(satisfaction_rating, '$.reason')          AS satisfaction_reason
FROM {{ source('zendesk', 'ticket') }}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
