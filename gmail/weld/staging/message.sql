-- staging.gmail.message
-- Thin wrapper over raw `message`: one row per email in the connected mailbox. Casts the
-- epoch-millisecond `internal_date` to a timestamp and de-duplicates.
--
-- Grain: message_id.
-- `internal_date` is when Gmail received the message (or, for sent mail, when it was
-- sent), in UTC. It is the date Gmail itself sorts by, and more reliable than the Date
-- header, which the sender's client sets. Spam and Trash are not synced.

SELECT
    CAST(id AS STRING)                              AS message_id,
    CAST(thread_id AS STRING)                       AS thread_id,
    TIMESTAMP_MILLIS(CAST(internal_date AS INT64))  AS sent_or_received_at,
    CAST(size_estimate AS INT64)                    AS size_bytes,
    CAST(snippet AS STRING)                         AS snippet
FROM {{raw.gmail.message}}
WHERE internal_date IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _weld_synced DESC) = 1
