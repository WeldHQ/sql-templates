-- core.salesforce.aggregated_daily_sales_report
-- One row per calendar day with the day's CRM activity: leads in, leads
-- converted, closed tasks, events, and opportunities opened, won and lost.
--
-- Grain: day. The calendar runs from the first day with any activity to today,
-- or further if open pipeline is expected to close later, so quiet days show
-- up as zeros instead of going missing.
--
-- Each metric is dated on its own event: leads on created date, conversions on
-- converted date, tasks on their activity (due) date, events on their start,
-- new opportunities on created date, won/lost/open pipeline on close date.
-- Days are UTC; Weld lands Salesforce date and datetime fields as timestamps.
-- Deleted records (is_deleted) are left out. Amounts are in the org's
-- currency as Salesforce stores them; multi-currency orgs are not converted.
--
-- Depends on: raw.salesforce.lead, task, event, opportunity
--
-- From the weld.app template library, rewritten and corrected. Not reconciled
-- against Salesforce; check the output against the source before relying on it.

WITH lead_days AS (
    SELECT DATE(created_date) AS day, 'lead_created' AS metric, CAST(NULL AS FLOAT64) AS value
    FROM {{raw.salesforce.lead}}
    WHERE NOT COALESCE(is_deleted, FALSE)

    UNION ALL

    SELECT DATE(converted_date), 'lead_converted', NULL
    FROM {{raw.salesforce.lead}}
    WHERE NOT COALESCE(is_deleted, FALSE)
      AND is_converted
),

activity_days AS (
    -- A task counts once it is closed, on its activity date. Tasks with no
    -- activity date have no day to land on and are left out.
    SELECT DATE(activity_date) AS day, 'task_completed' AS metric, CAST(NULL AS FLOAT64) AS value
    FROM {{raw.salesforce.task}}
    WHERE NOT COALESCE(is_deleted, FALSE)
      AND is_closed

    UNION ALL

    -- Timed events carry activity_date_time; all-day events only activity_date.
    SELECT DATE(COALESCE(activity_date_time, activity_date)), 'event_held', NULL
    FROM {{raw.salesforce.event}}
    WHERE NOT COALESCE(is_deleted, FALSE)
),

opportunity_days AS (
    SELECT DATE(created_date) AS day, 'opp_created' AS metric, CAST(amount AS FLOAT64) AS value
    FROM {{raw.salesforce.opportunity}}
    WHERE NOT COALESCE(is_deleted, FALSE)

    UNION ALL

    -- Closed opportunities land on the close date as won or lost. Open ones in a
    -- live forecast category land on their expected close date as pipeline.
    SELECT
        DATE(close_date),
        CASE
            WHEN is_won THEN 'opp_won'
            WHEN is_closed THEN 'opp_lost'
            WHEN LOWER(forecast_category) IN ('pipeline', 'forecast', 'bestcase') THEN 'opp_pipeline'
        END,
        CAST(amount AS FLOAT64)
    FROM {{raw.salesforce.opportunity}}
    WHERE NOT COALESCE(is_deleted, FALSE)
),

per_day AS (
    SELECT
        day,
        COUNTIF(metric = 'lead_created')                       AS leads_created,
        COUNTIF(metric = 'lead_converted')                     AS leads_converted,
        COUNTIF(metric = 'opp_created')                        AS opportunities_created,
        SUM(IF(metric = 'opp_created', value, 0))              AS opportunities_created_amount,
        COUNTIF(metric = 'opp_won')                            AS opportunities_won,
        SUM(IF(metric = 'opp_won', value, 0))                  AS opportunities_won_amount,
        COUNTIF(metric = 'opp_lost')                           AS opportunities_lost,
        SUM(IF(metric = 'opp_lost', value, 0))                 AS opportunities_lost_amount,
        SUM(IF(metric = 'opp_pipeline', value, 0))             AS pipeline_amount,
        COUNTIF(metric = 'task_completed')                     AS tasks_completed,
        COUNTIF(metric = 'event_held')                         AS events_completed
    FROM (
        SELECT * FROM lead_days
        UNION ALL SELECT * FROM activity_days
        UNION ALL SELECT * FROM opportunity_days
    )
    WHERE day IS NOT NULL
      AND metric IS NOT NULL
    GROUP BY day
),

calendar AS (
    SELECT day
    FROM UNNEST(GENERATE_DATE_ARRAY(
        (SELECT MIN(day) FROM per_day),
        (SELECT GREATEST(MAX(day), CURRENT_DATE()) FROM per_day)
    )) AS day
)

SELECT
    c.day                                                      AS date_day,
    COALESCE(p.leads_created, 0)                               AS leads_created,
    COALESCE(p.leads_converted, 0)                             AS leads_converted,
    COALESCE(p.opportunities_created, 0)                       AS opportunities_created,
    ROUND(COALESCE(p.opportunities_created_amount, 0), 2)      AS opportunities_created_amount,
    COALESCE(p.opportunities_won, 0)                           AS opportunities_won,
    ROUND(COALESCE(p.opportunities_won_amount, 0), 2)          AS opportunities_won_amount,
    COALESCE(p.opportunities_lost, 0)                          AS opportunities_lost,
    ROUND(COALESCE(p.opportunities_lost_amount, 0), 2)         AS opportunities_lost_amount,
    ROUND(COALESCE(p.pipeline_amount, 0), 2)                   AS pipeline_amount,
    COALESCE(p.tasks_completed, 0)                             AS tasks_completed,
    COALESCE(p.events_completed, 0)                            AS events_completed
FROM calendar c
LEFT JOIN per_day p
  ON p.day = c.day
