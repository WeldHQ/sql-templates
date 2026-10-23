-- Sessions are unique, and every event with a user lands in exactly one session.
--
-- The session number is a running count of session starts per user and day. If two
-- events tie on time and the ordering is not deterministic, events can be split or lost;
-- comparing event totals against staging catches that.

SELECT 'duplicate_session_id' AS check_name, session_id AS detail
FROM {{ ref('core_mixpanel_source__sessions') }}
GROUP BY session_id
HAVING COUNT(*) > 1

UNION ALL

SELECT 'events_do_not_reconcile', CONCAT(CAST(s.total AS STRING), ' vs ', CAST(e.total AS STRING))
FROM (SELECT SUM(events) AS total FROM {{ ref('core_mixpanel_source__sessions') }}) s
CROSS JOIN (
    SELECT COUNT(*) AS total
    FROM {{ ref('stg_mixpanel_source__events') }}
    WHERE distinct_id IS NOT NULL
) e
WHERE s.total != e.total
