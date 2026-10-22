-- core_gmail__messages
-- One row per email with what every report needs: direction, sender, recipients, subject
-- and position in its thread. The base for the other Gmail models, and useful on its own.
--
-- Grain: one row per message (drafts excluded).
-- Depends on: staging.gmail.message, .message_label, .message_header, .profile
--
-- Direction comes from Gmail's SENT label: a message carrying it was sent from this
-- mailbox, anything else was received. That holds for mail sent from other clients over
-- the same account, and for "send as" aliases.
--
-- Addresses are pulled out of the From, To and Cc headers with a regular expression, so a
-- display name like "Ada <ada@example.com>" becomes ada@example.com. `counterpart` is the
-- other side of the conversation: the sender for received mail, the first To address for
-- sent mail.
--
-- Timestamps are UTC. Convert before taking DATE() if your day should follow your office.

WITH labels AS (
    SELECT
        message_id,
        LOGICAL_OR(label_id = 'SENT')           AS is_sent,
        LOGICAL_OR(label_id = 'DRAFT')          AS is_draft,
        LOGICAL_OR(label_id = 'INBOX')          AS is_in_inbox,
        LOGICAL_OR(label_id = 'UNREAD')         AS is_unread,
        LOGICAL_OR(label_id = 'IMPORTANT')      AS is_important,
        MAX(IF(STARTS_WITH(label_id, 'CATEGORY_'),
                     LOWER(SUBSTR(label_id, 10)), NULL)) AS inbox_category
    FROM {{ ref('stg_gmail__message_label') }}
    GROUP BY 1
),

headers AS (
    SELECT
        message_id,
        MAX(IF(header_name = 'from', header_value, NULL))    AS from_header,
        STRING_AGG(IF(header_name = 'to', header_value, NULL), ', ') AS to_header,
        STRING_AGG(IF(header_name = 'cc', header_value, NULL), ', ') AS cc_header,
        MAX(IF(header_name = 'subject', header_value, NULL)) AS subject
    FROM {{ ref('stg_gmail__message_header') }}
    WHERE header_name IN ('from', 'to', 'cc', 'subject')
    GROUP BY 1
),

enriched AS (
    SELECT
        m.message_id,
        m.thread_id,
        m.sent_or_received_at,
        IF(COALESCE(l.is_sent, FALSE), 'sent', 'received')         AS direction,
        COALESCE(l.is_draft, FALSE)                                 AS is_draft,
        COALESCE(l.is_in_inbox, FALSE)                              AS is_in_inbox,
        COALESCE(l.is_unread, FALSE)                                AS is_unread,
        COALESCE(l.is_important, FALSE)                             AS is_important,
        l.inbox_category,
        h.subject,
        REGEXP_EXTRACT(LOWER(h.from_header), r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]+') AS from_address,
        REGEXP_EXTRACT_ALL(LOWER(h.to_header), r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]+') AS to_addresses,
        REGEXP_EXTRACT_ALL(LOWER(h.cc_header), r'[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]+') AS cc_addresses,
        m.size_bytes,
        m.snippet
    FROM {{ ref('stg_gmail__message') }} m
    LEFT JOIN labels l  ON l.message_id = m.message_id
    LEFT JOIN headers h ON h.message_id = m.message_id
)

SELECT
    e.message_id,
    e.thread_id,
    e.sent_or_received_at,
    DATE(e.sent_or_received_at)                                     AS date,
    p.mailbox_address,
    e.direction,
    e.from_address,
    e.to_addresses,
    e.cc_addresses,
    IF(e.direction = 'sent', e.to_addresses[SAFE_OFFSET(0)], e.from_address) AS counterpart,
    REGEXP_EXTRACT(
        IF(e.direction = 'sent', e.to_addresses[SAFE_OFFSET(0)], e.from_address),
        r'@(.+)$')                                                  AS counterpart_domain,
    e.subject,
    e.is_in_inbox,
    e.is_unread,
    e.is_important,
    e.inbox_category,
    ROW_NUMBER() OVER (
        PARTITION BY e.thread_id
        ORDER BY e.sent_or_received_at, e.message_id)               AS position_in_thread,
    e.size_bytes,
    e.snippet
FROM enriched e
LEFT JOIN {{ ref('stg_gmail__profile') }} p ON TRUE
WHERE NOT e.is_draft
