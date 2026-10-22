-- One row per message sid and per call sid after staging.
--
-- The connector re-reads recent days on every sync, so raw holds repeats by design. If
-- the de-duplication in staging stops working, every count and every cost in the daily
-- models inflates by however often a message was re-read.

SELECT 'message' AS stream, message_sid AS sid, COUNT(*) AS row_count
FROM {{ ref('stg_twilio__message') }}
GROUP BY message_sid
HAVING COUNT(*) > 1

UNION ALL

SELECT 'call', call_sid, COUNT(*)
FROM {{ ref('stg_twilio__call') }}
GROUP BY call_sid
HAVING COUNT(*) > 1
