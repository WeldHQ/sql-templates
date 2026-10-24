-- core.zendesk.ticket_volume_by_day
-- Tickets created, solved and left unsolved per day: Zendesk's "Tickets" tab.
-- Grain: day x zendesk_account x group x channel.
-- Depends on: core.zendesk.ticket_lifecycle
--
-- Built on a day spine, so a group or channel with a quiet day still returns a
-- row of zeros and its backlog line keeps going instead of disappearing.
--
-- BACKLOG is every ticket created on or before the day that had not been
-- resolved by the end of it: running created minus running solved. Two limits,
-- both because the connector syncs a ticket's current state and not its history:
--   * A ticket is counted in the group and channel it has NOW. Reassigning a
--     ticket moves its whole history to the new group.
--   * Only the latest solve is known. A ticket solved in March, reopened in May
--     and solved again in June counts as unsolved from creation to June.
-- The last day of the series ties exactly to Zendesk's current unsolved count
-- (see dbt/tests/assert_zendesk__backlog_ties_to_unsolved.sql); earlier days are a
-- reconstruction. For an exact history, materialise this model daily and keep
-- the runs.
--
-- tickets_solved counts tickets by their latest solve date. Explore's "Solved
-- tickets" counts solve events, so a ticket solved twice counts twice there.

WITH tickets AS (
    SELECT
        zendesk_account,
        IFNULL(group_id, '')  AS group_key,
        group_id,
        group_name,
        channel,
        created_date,
        resolved_date
    FROM {{core.zendesk.ticket_lifecycle}}
    WHERE created_date IS NOT NULL
),

day_spine AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(created_date) FROM tickets),
        -- Local dates can run a day ahead of UTC, so never stop before the
        -- latest event.
        GREATEST(CURRENT_DATE(),
                 (SELECT MAX(created_date) FROM tickets),
                 (SELECT IFNULL(MAX(resolved_date), CURRENT_DATE()) FROM tickets))
    )) AS day
),

dims AS (
    SELECT
        zendesk_account,
        group_key,
        channel,
        ANY_VALUE(group_id)   AS group_id,
        ANY_VALUE(group_name) AS group_name,
        MIN(created_date)     AS first_day
    FROM tickets
    GROUP BY 1, 2, 3
),

grid AS (
    SELECT s.day, d.zendesk_account, d.group_key, d.channel, d.group_id, d.group_name
    FROM day_spine s
    CROSS JOIN dims d
    -- No leading empty years for a group or channel that appeared late.
    WHERE s.day >= d.first_day
),

events AS (
    SELECT zendesk_account, group_key, channel, created_date AS day,
           1 AS created, 0 AS solved
    FROM tickets
    UNION ALL
    SELECT zendesk_account, group_key, channel, resolved_date AS day,
           0 AS created, 1 AS solved
    FROM tickets
    WHERE resolved_date IS NOT NULL
),

daily AS (
    SELECT zendesk_account, group_key, channel, day,
           SUM(created) AS tickets_created,
           SUM(solved)  AS tickets_solved
    FROM events
    GROUP BY 1, 2, 3, 4
),

joined AS (
    SELECT
        g.day,
        g.zendesk_account,
        g.group_key,
        g.group_id,
        g.group_name,
        g.channel,
        COALESCE(d.tickets_created, 0) AS tickets_created,
        COALESCE(d.tickets_solved, 0)  AS tickets_solved
    FROM grid g
    LEFT JOIN daily d
           ON d.zendesk_account = g.zendesk_account
          AND d.group_key       = g.group_key
          AND d.channel         = g.channel
          AND d.day             = g.day
)

SELECT
    day,
    zendesk_account,
    group_id,
    group_name,
    channel,
    tickets_created,
    tickets_solved,
    SUM(tickets_created - tickets_solved) OVER (
        PARTITION BY zendesk_account, group_key, channel
        ORDER BY day
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS unsolved_backlog_end_of_day
FROM joined
