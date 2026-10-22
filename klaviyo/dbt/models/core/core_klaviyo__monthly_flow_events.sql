-- core_klaviyo__monthly_flow_events
-- Monthly Flow Events. Generates a report of monthly flow events from the Klaviyo
-- integration. It calculates the total number of events triggered and the number of
-- distinct persons triggered for each flow in a given month. The result includes
-- the month, flow ID, flow name, flow status, trigger type, trigger filter,
-- customer filter, total events triggered, and distinct persons triggered, ordered
-- by month and flow name.
--
-- From the weld.app template library. Not reconciled against Klaviyo;
-- check the output against the source before relying on it.

WITH MonthlyFlowEvents AS (
    SELECT
      
        date_trunc(e.timestamp,month) AS month,
        e.flow_id,
        COUNT(DISTINCT e.id) AS total_events_triggered,
        COUNT(DISTINCT e.person_id) AS distinct_persons_triggered
    FROM
       {{ source('klaviyo', 'event') }} e
    WHERE
        e.flow_id IS NOT NULL
    GROUP BY
       month, e.flow_id
)

SELECT
   
    mfe.month,
    f.id AS flow_id,
    f.name AS flow_name,
    f.status AS flow_status,
    f.trigger_type AS trigger_type,
    f.trigger_filter AS trigger_filter,
    f.customer_filter AS customer_filter,
    mfe.total_events_triggered,
    mfe.distinct_persons_triggered
FROM
    MonthlyFlowEvents mfe
JOIN
   {{ source('klaviyo', 'flow') }} f ON mfe.flow_id = f.id
ORDER BY
 mfe.month DESC, f.name
