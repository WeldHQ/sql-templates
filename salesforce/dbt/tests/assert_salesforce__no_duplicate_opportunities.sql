-- One row per opportunity, per org.
--
-- The connector merges on id, so duplicates should not happen. This catches the
-- ways they appear anyway: a second org unioned into staging under the same
-- salesforce_org label, or a stage or account lookup that stops being unique.
-- Every other model reads opportunity_pipeline, so run this one first.

SELECT
    salesforce_org,
    opportunity_id,
    COUNT(*) AS rows_for_opportunity
FROM {{ ref('core_salesforce__opportunity_pipeline') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
