-- staging.freshdesk.agent
-- Thin wrapper over raw `agent`. One row per agent. An agent's id is the same id
-- Freshdesk uses for that person as a user, so it matches ticket.responder_id,
-- ticket_conversation.user_id and satisfaction_rating.agent_id.

SELECT
    'account_1'                                          AS freshdesk_account,
    CAST(id AS STRING)                                   AS agent_id,
    NULLIF(TRIM(CAST(contact_name AS STRING)), '')       AS agent_name,
    LOWER(NULLIF(TRIM(CAST(contact_email AS STRING)), '')) AS agent_email,
    COALESCE(CAST(deactivated AS BOOL), FALSE)           AS is_deactivated,
    CAST(occasional AS BOOL)                             AS is_occasional
FROM {{raw.freshdesk.agent}}
WHERE id IS NOT NULL
