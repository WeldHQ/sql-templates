-- core_gorgias__ticket_volume_by_day
-- Tickets created, closed and left open per day: the "Overview" volume charts.
-- Grain: day x gorgias_account x team x channel.
-- Depends on: core.gorgias.ticket_lifecycle
--
-- Built on a day spine, so a quiet team or channel returns zeros.
--
-- tickets_closed counts tickets on their LATEST close. Gorgias' "Tickets closed"
-- counts close events, so a ticket closed, reopened and closed again counts twice
-- there and once here. The connector can sync every close event into an
-- `event_ticket_closed` table if you enable that event type; it is not required
-- by these templates.
--
-- OPEN BACKLOG is running created minus running closed, each ticket in the team
-- and channel it has now. The last day equals today's open ticket count; earlier
-- days are a reconstruction, because a reopened ticket counts as open from
-- creation to its last close. Snoozed tickets are open in Gorgias and count here.

WITH tickets AS (
    SELECT
        gorgias_account,
        IFNULL(team_id, '') AS team_key,
        team_id,
        team_name,
        channel,
        created_date,
        resolved_date
    FROM {{ ref('core_gorgias__ticket_lifecycle') }}
),

dims AS (
    SELECT
        gorgias_account,
        team_key,
        channel,
        ANY_VALUE(team_id)   AS team_id,
        ANY_VALUE(team_name) AS team_name,
        MIN(created_date)    AS first_day
    FROM tickets
    GROUP BY 1, 2, 3
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(created_date) FROM tickets),
        GREATEST(CURRENT_DATE(),
                 (SELECT MAX(created_date) FROM tickets),
                 (SELECT IFNULL(MAX(resolved_date), CURRENT_DATE()) FROM tickets))
    )) AS day
),

events AS (
    SELECT gorgias_account, team_key, channel, created_date AS day, 1 AS created, 0 AS closed
    FROM tickets
    UNION ALL
    SELECT gorgias_account, team_key, channel, resolved_date AS day, 0, 1
    FROM tickets
    WHERE resolved_date IS NOT NULL
),

daily AS (
    SELECT gorgias_account, team_key, channel, day,
           SUM(created) AS tickets_created,
           SUM(closed)  AS tickets_closed
    FROM events
    GROUP BY 1, 2, 3, 4
),

joined AS (
    SELECT
        s.day,
        d.gorgias_account,
        d.team_key,
        d.team_id,
        d.team_name,
        d.channel,
        COALESCE(x.tickets_created, 0) AS tickets_created,
        COALESCE(x.tickets_closed, 0)  AS tickets_closed
    FROM day_spine s
    CROSS JOIN dims d
    LEFT JOIN daily x
           ON x.gorgias_account = d.gorgias_account
          AND x.team_key        = d.team_key
          AND x.channel         = d.channel
          AND x.day             = s.day
    WHERE s.day >= d.first_day
)

SELECT
    day,
    gorgias_account,
    team_id,
    team_name,
    channel,
    tickets_created,
    tickets_closed,
    SUM(tickets_created - tickets_closed) OVER (
        PARTITION BY gorgias_account, team_key, channel
        ORDER BY day
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS open_backlog_end_of_day
FROM joined
