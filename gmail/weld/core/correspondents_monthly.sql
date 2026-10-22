-- core.gmail.correspondents_monthly
-- Who the mailbox talks to, per month: messages received from and sent to each address.
--
-- Grain: one row per month x correspondent address.
-- Depends on: core.gmail.messages
--
-- Received mail is counted against the sender. Sent mail is counted against every To and
-- Cc address, so one message to three people adds one to each of them; `messages_sent`
-- therefore sums to more than the number of messages sent. The mailbox's own address is
-- left out.

WITH received AS (
    SELECT
        DATE_TRUNC(date, MONTH)             AS month,
        from_address                        AS correspondent,
        1                                   AS is_received
    FROM {{core.gmail.messages}}
    WHERE direction = 'received'
      AND from_address IS NOT NULL
),

sent AS (
    SELECT
        DATE_TRUNC(m.date, MONTH)           AS month,
        recipient                           AS correspondent,
        0                                   AS is_received
    FROM {{core.gmail.messages}} m,
         UNNEST(ARRAY_CONCAT(m.to_addresses, m.cc_addresses)) AS recipient
    WHERE m.direction = 'sent'
      AND recipient IS DISTINCT FROM m.mailbox_address
)

SELECT
    month,
    correspondent,
    REGEXP_EXTRACT(correspondent, r'@(.+)$')    AS correspondent_domain,
    COUNTIF(is_received = 1)                    AS messages_received,
    COUNTIF(is_received = 0)                    AS messages_sent
FROM (
    SELECT * FROM received
    UNION ALL
    SELECT * FROM sent
)
GROUP BY 1, 2, 3
