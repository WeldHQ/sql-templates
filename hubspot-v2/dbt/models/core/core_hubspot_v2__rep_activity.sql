-- core_hubspot_v2__rep_activity
-- Calls, emails, meetings, notes and tasks logged per owner per day.
-- Grain: day x owner. Day is in the portal's time zone.
-- Depends on: staging.hubspot_v2.engagement, .owner, .account_details
--
-- Recreates HubSpot's "Activities" report (activities by type and assigned user).
-- Activities land on the day they happened (`timestamp` in HubSpot), not the day
-- they were logged: a call logged on Monday for last Friday counts on Friday.
--
-- WHAT COUNTS AS WHAT. HubSpot's engagement types are mapped as follows:
--   emails    EMAIL (sent from HubSpot or logged), INCOMING_EMAIL, FORWARDED_EMAIL
--   calls     CALL; connected_calls are calls with status COMPLETED
--   meetings  MEETING; meetings_completed have outcome COMPLETED
--   notes     NOTE
--   tasks     TASK, counted on their due/occurrence date; tasks_completed have
--             status COMPLETED. HubSpot does not expose the completion day here,
--             so completed tasks sit on the task's own date.
-- Anything else (e.g. CONVERSATION_SESSION) is counted in other_activities so
-- the total always reconciles to the raw row count.
--
-- Activities with no owner are kept under owner_id NULL rather than dropped.

WITH portal AS (
    SELECT hubspot_portal, time_zone FROM {{ ref('stg_hubspot_v2__account_details') }}
),

activity AS (
    SELECT
        e.hubspot_portal,
        DATE(e.occurred_at, COALESCE(p.time_zone, 'UTC')) AS activity_date,
        e.owner_id,
        COUNT(*)                                                           AS total_activities,
        COUNTIF(e.engagement_type IN ('EMAIL', 'INCOMING_EMAIL', 'FORWARDED_EMAIL')) AS emails,
        COUNTIF(e.engagement_type = 'CALL')                                AS calls,
        COUNTIF(e.engagement_type = 'CALL' AND e.status = 'COMPLETED')     AS connected_calls,
        SUM(CASE WHEN e.engagement_type = 'CALL' THEN e.call_duration_minutes END) AS call_minutes,
        COUNTIF(e.engagement_type = 'MEETING')                             AS meetings,
        COUNTIF(e.engagement_type = 'MEETING' AND e.meeting_outcome = 'COMPLETED') AS meetings_completed,
        COUNTIF(e.engagement_type = 'NOTE')                                AS notes,
        COUNTIF(e.engagement_type = 'TASK')                                AS tasks,
        COUNTIF(e.engagement_type = 'TASK' AND e.status = 'COMPLETED')     AS tasks_completed,
        COUNTIF(e.engagement_type NOT IN ('EMAIL', 'INCOMING_EMAIL', 'FORWARDED_EMAIL',
                                          'CALL', 'MEETING', 'NOTE', 'TASK')) AS other_activities
    FROM {{ ref('stg_hubspot_v2__engagement') }} e
    LEFT JOIN portal p
           ON p.hubspot_portal = e.hubspot_portal
    WHERE e.occurred_at IS NOT NULL
    GROUP BY 1, 2, 3
),

date_spine AS (
    SELECT day AS activity_date
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(activity_date) FROM activity),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS day
),

owners AS (
    -- Owners who have logged anything. Spining every HubSpot user would pad the
    -- output with admin and integration logins.
    SELECT DISTINCT hubspot_portal, owner_id, COALESCE(owner_id, 'unassigned') AS owner_key
    FROM activity
)

SELECT
    s.activity_date,
    o.hubspot_portal,
    o.owner_id,
    ow.owner_name,
    ow.owner_email,
    ow.owner_is_active,
    COALESCE(a.total_activities, 0)   AS total_activities,
    COALESCE(a.emails, 0)             AS emails,
    COALESCE(a.calls, 0)              AS calls,
    COALESCE(a.connected_calls, 0)    AS connected_calls,
    -- NULL rather than 0 on days without calls, so an average over the column is
    -- not dragged down by empty days.
    a.call_minutes,
    COALESCE(a.meetings, 0)           AS meetings,
    COALESCE(a.meetings_completed, 0) AS meetings_completed,
    COALESCE(a.notes, 0)              AS notes,
    COALESCE(a.tasks, 0)              AS tasks,
    COALESCE(a.tasks_completed, 0)    AS tasks_completed,
    COALESCE(a.other_activities, 0)   AS other_activities,
    -- Touchpoints with a person on the other end.
    COALESCE(a.calls, 0) + COALESCE(a.meetings, 0) AS live_touchpoints
FROM date_spine s
CROSS JOIN owners o
LEFT JOIN activity a
       ON a.activity_date                     = s.activity_date
      AND a.hubspot_portal                    = o.hubspot_portal
      AND COALESCE(a.owner_id, 'unassigned')  = o.owner_key
LEFT JOIN {{ ref('stg_hubspot_v2__owner') }} ow
       ON ow.hubspot_portal = o.hubspot_portal
      AND ow.owner_id       = o.owner_id
