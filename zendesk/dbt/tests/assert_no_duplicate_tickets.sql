-- One row per ticket, per Zendesk account.
--
-- The incremental ticket export can return a ticket twice and staging keeps the
-- latest version. This guards that, plus the two joins in ticket_lifecycle
-- (ticket_metric and user) that would fan a ticket out if either ever held two
-- rows for one key, which silently doubles every count downstream.

SELECT zendesk_account, ticket_id, COUNT(*) AS rows_for_ticket
FROM {{ ref('core_zendesk__ticket_lifecycle') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
