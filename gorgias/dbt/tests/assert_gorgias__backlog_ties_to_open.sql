-- The open backlog on the last day of the series must equal the number of
-- tickets that are open right now.
--
-- The backlog is reconstructed as running created minus running closed, so this
-- is the one day it can be checked against a number Gorgias shows directly. A
-- difference means a status other than open or closed, or a closed ticket
-- without a close date.

WITH last_day AS (
    SELECT gorgias_account, SUM(open_backlog_end_of_day) AS backlog
    FROM {{ ref('core_gorgias__ticket_volume_by_day') }}
    WHERE day = (SELECT MAX(day) FROM {{ ref('core_gorgias__ticket_volume_by_day') }})
    GROUP BY 1
),

open_now AS (
    SELECT gorgias_account, COUNTIF(NOT is_closed) AS open_tickets
    FROM {{ ref('core_gorgias__ticket_lifecycle') }}
    GROUP BY 1
)

SELECT o.gorgias_account, o.open_tickets, l.backlog
FROM open_now o
LEFT JOIN last_day l USING (gorgias_account)
WHERE l.backlog IS DISTINCT FROM o.open_tickets
