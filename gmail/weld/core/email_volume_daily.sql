-- core.gmail.email_volume_daily
-- How much mail the mailbox sends and receives per day, and with how many people.
--
-- Grain: one row per day (UTC) x direction (sent, received).
-- Depends on: core.gmail.messages
--
-- `threads` counts distinct conversations with activity that day; a thread active on
-- three days counts on each. `counterparts` counts distinct addresses on the other side,
-- per day, so it cannot be summed into unique people over a week.
-- Received mail includes newsletters and notifications. Filter on `inbox_category` in
-- core.gmail.messages (primary, promotions, social, updates, forums) if you only want
-- mail from people.

SELECT
    date,
    direction,
    COUNT(*)                                AS messages,
    COUNT(DISTINCT thread_id)               AS threads,
    COUNT(DISTINCT counterpart)             AS counterparts,
    COUNTIF(position_in_thread = 1)         AS new_threads,
    COUNTIF(direction = 'received' AND inbox_category = 'primary') AS received_primary,
    SUM(size_bytes)                         AS total_bytes
FROM {{core.gmail.messages}}
GROUP BY 1, 2
