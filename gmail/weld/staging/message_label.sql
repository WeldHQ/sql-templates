-- staging.gmail.message_label
-- Thin wrapper over raw `message_label`: the labels on each message, system labels
-- (INBOX, SENT, DRAFT, IMPORTANT, CATEGORY_PROMOTIONS and so on) and your own.
--
-- Grain: message_id x label_id.
-- Labels are captured when a message is synced. Archiving or relabelling a message later
-- does not change these rows unless the message is synced again.

SELECT DISTINCT
    CAST(message_id AS STRING)              AS message_id,
    CAST(label_id AS STRING)                AS label_id
FROM {{raw.gmail.message_label}}
WHERE label_id IS NOT NULL
