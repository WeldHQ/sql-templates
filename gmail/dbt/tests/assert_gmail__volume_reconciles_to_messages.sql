-- The daily volume adds back up to the message list, and no reply precedes its message.
--
-- The first half catches a grouping change in email_volume_daily that drops or doubles
-- rows. The second catches an ordering bug in response_times: a negative wait means the
-- "next sent message" window looked backwards.

SELECT 'volume' AS check_name, CAST(v.total AS STRING) AS detail
FROM (SELECT SUM(messages) AS total FROM {{ ref('core_gmail__email_volume_daily') }}) v
CROSS JOIN (SELECT COUNT(*) AS total FROM {{ ref('core_gmail__messages') }}) m
WHERE v.total != m.total

UNION ALL

SELECT 'negative_reply_time', message_id
FROM {{ ref('core_gmail__response_times') }}
WHERE minutes_to_reply < 0
