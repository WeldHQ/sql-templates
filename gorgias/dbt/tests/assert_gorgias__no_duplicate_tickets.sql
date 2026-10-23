-- One row per ticket, per Gorgias account.
--
-- The connector reads tickets from both the ticket list and merge events, and
-- staging keeps one version. This guards that, plus the message, survey and
-- first-reply joins in ticket_lifecycle, any of which would double every count
-- downstream if it ever returned two rows for one ticket.

SELECT gorgias_account, ticket_id, COUNT(*) AS rows_for_ticket
FROM {{ ref('core_gorgias__ticket_lifecycle') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
