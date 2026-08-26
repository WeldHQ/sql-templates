-- zoho_crm_rep_activity - calls, meetings and tasks logged per rep per day.
-- Grain: day x owner.
-- Depends on: staging.zoho_crm.call, .event, .task, .user
--
-- READ THIS BEFORE USING IT. This model counts activity per REP, never per deal,
-- account, contact or lead. That is not a design choice - Zoho's Calls, Events and
-- Tasks modules all carry What_Id / Who_Id pointing at the record the activity
-- belongs to, and the Weld connector does not sync either field. owner_id is the
-- only foreign key on all three streams.
--
-- So this model answers "how much is each rep doing" and cannot answer "how much
-- activity did we put into the deals we won". Any dashboard promising
-- activity-to-outcome attribution from this connector alone is inventing the link.
-- Until the connector syncs the parent ids, the join has to come from somewhere
-- else - a calendar or dialer source keyed on email, or Zoho's Notes module, whose
-- parent_id_id IS synced.
--
-- WHY THERE IS NO tasks_completed COLUMN: the connector syncs is_completed but no
-- completion timestamp. Completions can be counted as a current-state total, never
-- placed on a day. Booking them on modified_time would move a task's completion
-- every time anyone edited it afterwards.

WITH activity AS (
    SELECT zoho_org, owner_id, DATE(call_start_time) AS activity_date,
           1 AS calls_logged, call_duration_minutes AS call_minutes,
           0 AS events_held, 0 AS event_minutes,
           0 AS tasks_created
    FROM {{staging.zoho_crm.call}}
    WHERE call_start_time IS NOT NULL

    UNION ALL

    SELECT zoho_org, owner_id, DATE(start_date_time) AS activity_date,
           0, 0,
           1 AS events_held, duration_minutes AS event_minutes,
           0
    FROM {{staging.zoho_crm.event}}
    WHERE start_date_time IS NOT NULL

    UNION ALL

    -- Tasks land on the day they were CREATED, not their due date. Due dates get
    -- pushed; creation is when the rep actually did something.
    SELECT zoho_org, owner_id, DATE(created_time) AS activity_date,
           0, 0,
           0, 0,
           1 AS tasks_created
    FROM {{staging.zoho_crm.task}}
    WHERE created_time IS NOT NULL
),

rolled_up AS (
    SELECT
        activity_date,
        zoho_org,
        owner_id,
        SUM(calls_logged)  AS calls_logged,
        SUM(call_minutes)  AS call_minutes,
        SUM(events_held)   AS events_held,
        SUM(event_minutes) AS event_minutes,
        SUM(tasks_created) AS tasks_created
    FROM activity
    GROUP BY 1, 2, 3
),

date_spine AS (
    SELECT day AS activity_date
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(activity_date) FROM rolled_up),
        CURRENT_DATE(),
        INTERVAL 1 DAY
    )) AS day
),

owners AS (
    -- Reps who have logged anything at all. Spining every Zoho user against every
    -- day would bury the active team under admin and integration logins.
    SELECT DISTINCT zoho_org, owner_id FROM rolled_up
),

grid AS (
    SELECT s.activity_date, o.zoho_org, o.owner_id
    FROM date_spine s
    CROSS JOIN owners o
)

SELECT
    g.activity_date,
    g.zoho_org,
    g.owner_id,
    u.full_name AS owner_name,
    u.email     AS owner_email,
    u.role_name AS owner_role,
    u.is_active AS owner_is_active,

    COALESCE(r.calls_logged, 0)  AS calls_logged,
    -- NULL rather than 0 when no call was logged: a zero here would drag down any
    -- average-call-length metric computed over the column.
    r.call_minutes,
    COALESCE(r.events_held, 0)   AS events_held,
    r.event_minutes,
    COALESCE(r.tasks_created, 0) AS tasks_created,

    COALESCE(r.calls_logged, 0)
      + COALESCE(r.events_held, 0)
      + COALESCE(r.tasks_created, 0) AS total_activities,
    -- Touchpoints that involved a human on the other end, which is usually the
    -- number a sales lead actually wants out of an activity report.
    COALESCE(r.calls_logged, 0)
      + COALESCE(r.events_held, 0)   AS live_touchpoints
FROM grid g
LEFT JOIN rolled_up r
       ON r.activity_date = g.activity_date
      AND r.zoho_org      = g.zoho_org
      AND r.owner_id      = g.owner_id
LEFT JOIN {{staging.zoho_crm.user}} u
       ON u.zoho_org = g.zoho_org
      AND u.user_id  = g.owner_id
ORDER BY g.activity_date, owner_name
