-- One row per incident after de-duplication in staging.
-- Recently updated incidents are read again on every sync, so the raw table
-- can hold several versions of one incident. Without the de-duplication every
-- count and every MTTR would be inflated by the number of re-reads.

SELECT
    incident_id,
    COUNT(*) AS row_count
FROM {{ ref('stg_pager_duty__raw_incident') }}
GROUP BY 1
HAVING COUNT(*) > 1
