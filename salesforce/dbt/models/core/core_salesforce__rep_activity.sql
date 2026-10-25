-- core_salesforce__rep_activity
-- Calls, emails, completed tasks and meetings logged per rep per day.
-- Grain: date_day x salesforce_org x owner_id.
-- Depends on: staging.salesforce.task, .event, .user
--
-- WHICH DAY AN ACTIVITY LANDS ON:
--   calls and emails  -> the task's Date (activity_date): the day of the logged
--                        call or email. Falls back to the created day if empty.
--   completed tasks   -> other closed tasks, on their Date, which for a to-do is
--                        the due date. The connector's standard fields carry no
--                        completion timestamp that every org has, so the due
--                        date is the closest stable day.
--   tasks created     -> the day the task was created.
--   meetings          -> the event's start day. Only events that have started
--                        count; future meetings are scheduled, not held.
--
-- Nothing after today is counted. Each activity is counted once, for its owner.
-- Activities that hang off a record (what_id, who_id, account_id) are kept in
-- staging for anyone who wants them per opportunity or account; this model is
-- per rep only.

WITH activity AS (
    SELECT
        salesforce_org,
        owner_id,
        COALESCE(activity_date, DATE(created_at))                  AS date_day,
        IF(task_subtype = 'Call' OR (task_subtype IS NULL AND task_type = 'Call'), 1, 0) AS calls,
        IF(task_subtype = 'Call' OR (task_subtype IS NULL AND task_type = 'Call'),
           call_duration_seconds / 60.0, NULL)                     AS call_minutes,
        IF(task_subtype IN ('Email', 'ListEmail')
           OR (task_subtype IS NULL AND task_type = 'Email'), 1, 0) AS emails,
        IF(is_closed
           AND COALESCE(task_subtype, 'Task') NOT IN ('Call', 'Email', 'ListEmail')
           AND COALESCE(task_type, '') NOT IN ('Call', 'Email'), 1, 0) AS tasks_completed,
        0                                                          AS tasks_created,
        0                                                          AS meetings,
        CAST(NULL AS FLOAT64)                                      AS meeting_minutes
    FROM {{ ref('stg_salesforce__task') }}

    UNION ALL

    SELECT
        salesforce_org,
        owner_id,
        DATE(created_at),
        0, NULL, 0, 0,
        1                                                          AS tasks_created,
        0, NULL
    FROM {{ ref('stg_salesforce__task') }}

    UNION ALL

    SELECT
        salesforce_org,
        owner_id,
        event_date,
        0, NULL, 0, 0, 0,
        1                                                          AS meetings,
        -- All-day events carry 1440 minutes, which is not meeting time.
        IF(is_all_day_event, NULL, CAST(duration_minutes AS FLOAT64)) AS meeting_minutes
    FROM {{ ref('stg_salesforce__event') }}
    WHERE NOT COALESCE(is_recurrence, FALSE)
      AND COALESCE(starts_at <= CURRENT_TIMESTAMP(), event_date <= CURRENT_DATE())
),

rolled_up AS (
    SELECT
        date_day,
        salesforce_org,
        owner_id,
        SUM(calls)            AS calls_logged,
        SUM(call_minutes)     AS call_minutes,
        SUM(emails)           AS emails_logged,
        SUM(tasks_completed)  AS tasks_completed,
        SUM(tasks_created)    AS tasks_created,
        SUM(meetings)         AS meetings_held,
        SUM(meeting_minutes)  AS meeting_minutes
    FROM activity
    WHERE date_day IS NOT NULL
      AND date_day <= CURRENT_DATE()
    GROUP BY 1, 2, 3
),

day_spine AS (
    SELECT date_day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(date_day) FROM rolled_up),
        CURRENT_DATE()
    )) AS date_day
),

owners AS (
    -- Only people who have logged something, so the series is not padded with
    -- every user in the org.
    SELECT DISTINCT salesforce_org, owner_id FROM rolled_up
)

SELECT
    d.date_day,
    o.salesforce_org,
    o.owner_id,
    u.user_name                                    AS owner_name,
    u.email                                        AS owner_email,
    u.is_active                                    AS owner_is_active,

    COALESCE(r.calls_logged, 0)                    AS calls_logged,
    -- NULL, not 0, on days without calls, so an average over the column is not
    -- dragged down. Only calls logged with a duration contribute.
    r.call_minutes,
    COALESCE(r.emails_logged, 0)                   AS emails_logged,
    COALESCE(r.tasks_completed, 0)                 AS tasks_completed,
    COALESCE(r.tasks_created, 0)                   AS tasks_created,
    COALESCE(r.meetings_held, 0)                   AS meetings_held,
    r.meeting_minutes,
    COALESCE(r.calls_logged, 0)
      + COALESCE(r.emails_logged, 0)
      + COALESCE(r.meetings_held, 0)               AS touchpoints
FROM day_spine d
CROSS JOIN owners o
LEFT JOIN rolled_up r
       ON r.date_day       = d.date_day
      AND r.salesforce_org = o.salesforce_org
      AND r.owner_id       = o.owner_id
LEFT JOIN {{ ref('stg_salesforce__user') }} u
       ON u.salesforce_org = o.salesforce_org
      AND u.user_id        = o.owner_id
