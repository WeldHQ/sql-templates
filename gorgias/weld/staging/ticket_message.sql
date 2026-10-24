-- staging.gorgias.ticket_message
-- Thin wrapper over raw `ticket_message`: every message on every ticket, one row
-- per message. Casts and renames. Bodies are left out: large, and no report
-- needs them.
--
--   from_agent  TRUE when the message was sent from the helpdesk side. That
--               includes automated messages, which is why rule_id is kept.
--   rule_id     set when a Gorgias rule sent the message (auto-replies).
--   public      FALSE for internal notes.
-- sender is a JSON object; its id and name are unpacked for agent attribution.

SELECT
    'account_1'                                    AS gorgias_account,
    CAST(id AS STRING)                             AS message_id,
    CAST(ticket_id AS STRING)                      AS ticket_id,
    CAST(created_datetime AS TIMESTAMP)            AS created_at,
    CAST(sent_datetime AS TIMESTAMP)               AS sent_at,
    CAST(failed_datetime AS TIMESTAMP)             AS failed_at,
    COALESCE(CAST(from_agent AS BOOL), FALSE)      AS is_from_agent,
    COALESCE(CAST(public AS BOOL), TRUE)           AS is_public,
    CAST(rule_id AS STRING)                        AS rule_id,
    LOWER(CAST(channel AS STRING))                 AS channel,
    LOWER(CAST(via AS STRING))                     AS via,
    JSON_VALUE(sender, '$.id')                     AS sender_id,
    JSON_VALUE(sender, '$.name')                   AS sender_name
FROM {{raw.gorgias.ticket_message}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY created_datetime DESC) = 1
