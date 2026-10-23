-- The daily report counts every incident exactly once.
-- incident_response_daily groups raw_incident by day, service, team, urgency and
-- priority. If its total differs from the staging row count, a grouping column was
-- changed in a way that drops or duplicates incidents.

WITH report AS (
    SELECT SUM(incidents) AS incidents
    FROM {{ ref('core_pager_duty__incident_response_daily') }}
),

source AS (
    SELECT COUNT(*) AS incidents
    FROM {{ ref('stg_pager_duty__raw_incident') }}
)

SELECT *
FROM report, source
WHERE report.incidents != source.incidents
