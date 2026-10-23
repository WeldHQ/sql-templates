-- The daily series must account for every meeting exactly once when read through
-- org_meetings_scheduled, which counts each meeting on one host only.
--
-- A difference means the host fan-out leaked into the org-level count, or the date
-- spine dropped days. Returns zero rows when they agree.

WITH daily AS (
    SELECT calendly_account, SUM(org_meetings_scheduled) AS meetings
    FROM {{ ref('core_calendly__meetings_by_day') }}
    GROUP BY 1
),

events AS (
    SELECT calendly_account, COUNT(*) AS meetings
    FROM {{ ref('core_calendly__scheduled_events') }}
    WHERE start_time IS NOT NULL
    GROUP BY 1
)

SELECT
    COALESCE(d.calendly_account, e.calendly_account) AS calendly_account,
    d.meetings AS daily_meetings,
    e.meetings AS event_meetings
FROM daily d
FULL OUTER JOIN events e USING (calendly_account)
WHERE COALESCE(d.meetings, 0) <> COALESCE(e.meetings, 0)
