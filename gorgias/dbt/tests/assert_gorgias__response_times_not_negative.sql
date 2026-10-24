-- First response and resolution times are derived from timestamps, not taken
-- from Gorgias' statistics. A negative value means a message matched to the
-- wrong ticket or a close date older than the ticket, and would pull every
-- average and median towards an impossible zero.

SELECT gorgias_account, ticket_id, first_response_minutes, resolution_minutes
FROM {{ ref('core_gorgias__ticket_lifecycle') }}
WHERE first_response_minutes < 0
   OR resolution_minutes < 0
