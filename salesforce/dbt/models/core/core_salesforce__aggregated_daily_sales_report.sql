-- core_salesforce__aggregated_daily_sales_report
-- Aggregated Daily Salesforce Report. Extracts a day-by-day breakdown of CRM
-- activities on Salesforce, covering tasks, events, lead generation, and
-- opportunities. It integrates various data points to deliver insights such as
-- leads created, tasks completed, events held, and opportunity metrics.
--
-- From the weld.app template library. Not reconciled against Salesforce;
-- check the output against the source before relying on it.

WITH timeseries AS (
SELECT
day as date_day
FROM UNNEST(
GENERATE_DATE_ARRAY(DATE('2020-01-01'), '2099-12-31')
) AS day
),
task AS (
SELECT
DATE_TRUNC(activity_date, DAY) as activity_date,
COUNT(id) as tasks_completed
FROM {{ source('salesforce', 'task') }}
GROUP BY 1
),
salesforce_event AS (
SELECT
COALESCE(DATE_TRUNC(activity_date, DAY), DATE_TRUNC(activity_date_time, DAY)) as activity_date,
COUNT(id) as events_completed
FROM {{ source('salesforce', 'event') }}
GROUP BY 1
),
salesforce_lead AS (
SELECT
DATE_TRUNC(created_date, DAY) as created_date,
COUNT(id) as leads_created
FROM {{ source('salesforce', 'lead') }}
GROUP BY 1
),
salesforce_converted_lead AS (
SELECT
DATE_TRUNC(converted_date, DAY) as converted_date,
COUNT(id) as leads_converted
FROM {{ source('salesforce', 'lead') }}
WHERE is_converted
GROUP BY 1
),
opportunity AS (
SELECT
opportunity_id_c,
DATE_TRUNC(created_date, DAY) as created_date,
account_id,
DATE_TRUNC(close_date, DAY) as close_date,
is_closed,
is_deleted,
is_won,
owner_id,
stage_name,
type,
amount,
CASE
WHEN is_won THEN 'Won'
WHEN NOT is_won AND is_closed THEN 'Lost'
WHEN NOT is_closed AND LOWER(forecast_category) IN ('pipeline','forecast','bestcase') THEN 'Pipeline'
ELSE 'Other'
END as status
FROM {{ source('salesforce', 'opportunity') }}
),
opportunities_created AS (
SELECT
created_date,
COUNT(opportunity_id_c) as opportunities_created,
ROUND(SUM(amount)) as opportunities_created_amount
FROM opportunity
GROUP BY 1
),
opportunities_closed AS (
SELECT
close_date,
COUNT(CASE WHEN status = 'Won' THEN opportunity_id_c ELSE NULL END) as opportunities_won,
ROUND(SUM(CASE WHEN status = 'Won' THEN amount ELSE 0 END)) as opportunities_won_amount,
COUNT(CASE WHEN status = 'Lost' THEN opportunity_id_c ELSE NULL END) as opportunities_lost,
ROUND(SUM(CASE WHEN status = 'Lost' THEN amount ELSE NULL END)) as opportunities_lost_amount,
ROUND(SUM(CASE WHEN status = 'Pipeline' THEN amount ELSE NULL END)) as pipeline_amount
FROM opportunity
GROUP BY 1
)
SELECT
timeseries.date_day,
salesforce_lead.leads_created,
salesforce_converted_lead.leads_converted,
task.tasks_completed,
salesforce_event.events_completed,
opportunities_created.opportunities_created,
opportunities_created.opportunities_created_amount,
opportunities_closed.opportunities_won,
opportunities_closed.opportunities_won_amount,
opportunities_closed.opportunities_lost,
opportunities_closed.opportunities_lost_amount,
opportunities_closed.pipeline_amount
FROM timeseries
LEFT JOIN salesforce_lead
ON timeseries.date_day = cast(salesforce_lead.created_date as date)
LEFT JOIN salesforce_converted_lead
ON timeseries.date_day = cast(salesforce_converted_lead.converted_date as date)
LEFT JOIN task
ON timeseries.date_day = cast(task.activity_date as date)
LEFT JOIN salesforce_event
ON timeseries.date_day = cast(salesforce_event.activity_date as date)
LEFT JOIN opportunities_created
ON timeseries.date_day = cast(opportunities_created.created_date as date)
LEFT JOIN opportunities_closed
ON timeseries.date_day = cast(opportunities_closed.close_date as date)
