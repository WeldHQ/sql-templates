-- core_gmail__response_times
-- How long received email waits for a reply from this mailbox.
--
-- Grain: one row per received message that opens a wait: the first received message in
-- a thread after the start or after the mailbox's last reply. Follow-ups that arrive
-- before you answer belong to the same wait and are not counted again.
-- Depends on: core.gmail.messages
--
-- `replied_at` is the first message sent from this mailbox in the same thread after the
-- wait opened. A wait with no reply yet has `replied_at` NULL and stays open, so averages
-- should be taken over `is_replied` rows, and the open rows read as the backlog.
--
-- The clock is wall time, not business hours: a message received on Friday evening and
-- answered on Monday morning shows the whole weekend. Mail from automated senders
-- (newsletters, notifications) inflates the unreplied count; filter on `inbox_category`
-- or `counterpart_domain` to restrict to the conversations you care about.

WITH ordered AS (
    SELECT
        message_id,
        thread_id,
        sent_or_received_at,
        direction,
        counterpart,
        counterpart_domain,
        subject,
        inbox_category,
        LAG(direction) OVER (
            PARTITION BY thread_id ORDER BY sent_or_received_at, message_id) AS previous_direction,
        MIN(IF(direction = 'sent', sent_or_received_at, NULL)) OVER (
            PARTITION BY thread_id ORDER BY sent_or_received_at, message_id
            ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING)                AS next_sent_at
    FROM {{ ref('core_gmail__messages') }}
)

SELECT
    message_id,
    thread_id,
    sent_or_received_at                                             AS received_at,
    DATE(sent_or_received_at)                                       AS received_date,
    counterpart                                                     AS from_address,
    counterpart_domain                                              AS from_domain,
    subject,
    inbox_category,
    next_sent_at                                                    AS replied_at,
    next_sent_at IS NOT NULL                                        AS is_replied,
    TIMESTAMP_DIFF(next_sent_at, sent_or_received_at, MINUTE)       AS minutes_to_reply
FROM ordered
WHERE direction = 'received'
  AND (previous_direction IS NULL OR previous_direction = 'sent')
