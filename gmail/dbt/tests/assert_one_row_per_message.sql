-- One row per message in core_gmail__messages.
--
-- The model joins labels and headers onto each message. Both are aggregated per message
-- first; if either stops being one row per message, every count downstream multiplies.

SELECT message_id, COUNT(*) AS row_count
FROM {{ ref('core_gmail__messages') }}
GROUP BY message_id
HAVING COUNT(*) > 1
