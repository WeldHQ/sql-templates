-- staging.freshdesk.ticket_conversation
-- Thin wrapper over raw `ticket_conversation`: every reply and note on a ticket,
-- one row per conversation. Casts and renames, keeps the latest version of each.
--
-- The ticket's first message (its description) is NOT a conversation in
-- Freshdesk, so a ticket with no replies has no rows here.
--
--   incoming      TRUE when the message came from outside the helpdesk (the customer)
--   is_private    TRUE for private notes
--   source_code   0 reply, 2 note; other codes are channel-specific (phone, social, ...)
--   auto_response TRUE for automated replies
-- Message bodies are left out on purpose: they are large and no report needs them.

SELECT
    'account_1'                                AS freshdesk_account,
    CAST(id AS STRING)                         AS conversation_id,
    CAST(ticket_id AS STRING)                  AS ticket_id,
    CAST(user_id AS STRING)                    AS user_id,
    CAST(created_at AS TIMESTAMP)              AS created_at,
    CAST(incoming AS BOOL)                     AS is_incoming,
    CAST(private AS BOOL)                      AS is_private,
    CAST(source AS INT64)                      AS source_code,
    COALESCE(CAST(auto_response AS BOOL), FALSE) AS is_auto_response
FROM {{raw.freshdesk.ticket_conversation}}
WHERE id IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY updated_at DESC) = 1
