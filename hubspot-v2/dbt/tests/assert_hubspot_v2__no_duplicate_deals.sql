-- One row per deal in deal_pipeline.
--
-- The model joins deals to stages, owners and one company. Each of those joins is
-- meant to be one-to-one; if any of them fans out (a stage id present in two
-- pipelines with the same id, a duplicated owner row, the company pick no longer
-- returning one row per deal), deal amounts are silently counted twice in every
-- report built on top. This test is the guard.

SELECT
    hubspot_portal,
    deal_id,
    COUNT(*) AS row_count
FROM {{ ref('core_hubspot_v2__deal_pipeline') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
