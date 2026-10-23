-- Response timings are never negative and counts never exceed incidents.
-- A negative total means a timing column was parsed or signed wrongly in staging.

SELECT *
FROM {{ ref('core_pager_duty__incident_response_daily') }}
WHERE total_seconds_to_first_ack < 0
   OR total_seconds_to_resolve < 0
   OR acknowledged_incidents > incidents
   OR resolved_incidents > incidents
