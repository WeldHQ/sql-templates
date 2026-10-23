-- A first response cannot precede the ticket.
--
-- First response is derived from the conversation log, not taken from
-- Freshdesk's stats. A negative time means a conversation was matched to the
-- wrong ticket or a timestamp was cast in the wrong zone, and either would drag
-- every average and median down while looking like excellent service.

SELECT freshdesk_account, ticket_id, created_at, first_response_at, first_response_minutes
FROM {{ ref('core_freshdesk__ticket_lifecycle') }}
WHERE first_response_minutes < 0
