-- Tickets solved per month must agree between the daily volume model and the
-- monthly response-time model. Both read ticket_lifecycle with the same solve
-- date, so a difference means a filter drifted in one of them.

WITH daily AS (
    SELECT zendesk_account, DATE_TRUNC(day, MONTH) AS month, SUM(tickets_solved) AS solved
    FROM {{ ref('core_zendesk__ticket_volume_by_day') }}
    GROUP BY 1, 2
),

monthly AS (
    SELECT zendesk_account, month, SUM(tickets_solved) AS solved
    FROM {{ ref('core_zendesk__response_times_by_month') }}
    GROUP BY 1, 2
)

SELECT *
FROM daily d
FULL OUTER JOIN monthly m USING (zendesk_account, month)
WHERE COALESCE(d.solved, 0) != COALESCE(m.solved, 0)
