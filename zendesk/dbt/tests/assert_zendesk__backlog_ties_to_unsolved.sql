-- The backlog on the last day of the series must equal the number of tickets
-- that are unsolved right now.
--
-- The backlog is reconstructed as running created minus running solved, so this
-- is the one day where it can be checked against a number Zendesk states
-- directly. A difference means a status the model does not classify as either
-- solved or unsolved, or a solved ticket without a resolved date.

WITH last_day AS (
    SELECT zendesk_account, SUM(unsolved_backlog_end_of_day) AS backlog
    FROM {{ ref('core_zendesk__ticket_volume_by_day') }}
    WHERE day = (SELECT MAX(day) FROM {{ ref('core_zendesk__ticket_volume_by_day') }})
    GROUP BY 1
),

unsolved AS (
    SELECT zendesk_account, COUNTIF(NOT is_solved) AS unsolved_tickets
    FROM {{ ref('core_zendesk__ticket_lifecycle') }}
    WHERE created_date IS NOT NULL
    GROUP BY 1
)

SELECT u.zendesk_account, u.unsolved_tickets, l.backlog
FROM unsolved u
LEFT JOIN last_day l USING (zendesk_account)
WHERE l.backlog IS DISTINCT FROM u.unsolved_tickets
