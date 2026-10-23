-- One row per ticket, per helpdesk.
--
-- ticket_lifecycle joins replies, ratings, groups and agents onto the ticket. If
-- any of those ever held two rows for one key (a second helpdesk unioned in
-- staging under the same label, or an agent synced twice), every count
-- downstream would double without an error.

SELECT freshdesk_account, ticket_id, COUNT(*) AS rows_for_ticket
FROM {{ ref('core_freshdesk__ticket_lifecycle') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
