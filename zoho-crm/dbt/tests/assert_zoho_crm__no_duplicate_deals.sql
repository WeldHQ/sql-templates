-- One row per deal, per org.
--
-- The Zoho connector merges on `id`, so duplicates should be impossible. This
-- guards the two ways they appear anyway: a second Zoho org unioned into the
-- staging models without changing the zoho_org label, and a ReSync that lands
-- alongside the existing table instead of replacing it.
--
-- Worth keeping even though it "cannot fail" - it is the cheapest test here and
-- silent row duplication doubles every amount in the pipeline.

SELECT
    zoho_org,
    deal_id,
    COUNT(*) AS rows_for_deal
FROM {{ ref('core_zoho_crm__deal_pipeline') }}
GROUP BY 1, 2
HAVING COUNT(*) > 1
