-- core.klaviyo.monthly_flow_events
-- Monthly Flow Events. Generates a report of monthly flow events from the Klaviyo
-- integration. It calculates the total number of events triggered and the number of
-- distinct persons triggered for each flow in a given month. The result includes
-- the month, flow ID, flow name, flow status, trigger type, total events triggered,
-- and distinct persons triggered, ordered by month and flow name.
--
-- Events are tied to a flow through Klaviyo's attribution data (the event's
-- flow_id). Persons are counted by Klaviyo profile id.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Klaviyo; check the output against the source before relying
-- on it.

WITH MonthlyFlowEvents AS (
    SELECT
        date_trunc(date(e.timestamp), month) AS month,
        e.flow_id,
        COUNT(DISTINCT e.id) AS total_events_triggered,
        COUNT(DISTINCT e.profile_id) AS distinct_persons_triggered
    FROM
       {{raw.klaviyo.event}} e
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
    mfe.total_events_triggered,
    mfe.distinct_persons_triggered
FROM
    MonthlyFlowEvents mfe
JOIN
   {{raw.klaviyo.flow}} f ON mfe.flow_id = f.id
ORDER BY
 mfe.month DESC, f.name
