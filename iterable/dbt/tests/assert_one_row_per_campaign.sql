-- One row per campaign in email_campaign_performance, and every event has a timestamp.
--
-- The campaign table joins six event aggregates and the campaign list; if the campaign
-- list ever holds a campaign twice, every metric doubles. Event times are parsed from
-- whatever type Iterable's data produced; a NULL means the format changed and those
-- events silently drop out of the daily series.

SELECT 'duplicate_campaign' AS check_name, campaign_id AS detail
FROM {{ ref('core_iterable__email_campaign_performance') }}
GROUP BY campaign_id
HAVING COUNT(*) > 1

UNION ALL

SELECT 'unparsed_send_time', message_id
FROM {{ ref('stg_iterable__email_send') }}
WHERE event_at IS NULL
