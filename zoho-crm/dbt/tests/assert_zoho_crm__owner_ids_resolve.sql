-- Deals whose owner_id does not exist in the user module.
--
-- Catches two real situations. Either the `user` stream is not being synced at all
-- - in which case every row in the pipeline has a NULL owner_name and nobody
-- notices until a dashboard groups by rep and shows one enormous blank bucket -
-- or a rep has been deleted from Zoho outright, taking their name with them while
-- their deals stay in the pipeline.
--
-- The core model joins user with a LEFT join precisely so these deals are not
-- silently dropped from the pipeline total. This test is how you find out they are
-- there.

SELECT
    owner_id,
    COUNT(*)                     AS deals,
    COUNTIF(is_open)             AS deals_open,
    SUM(pipeline_amount)         AS unattributed_open_pipeline
FROM {{ ref('core_zoho_crm__deal_pipeline') }}
WHERE owner_id IS NOT NULL
  AND owner_name IS NULL
GROUP BY 1
ORDER BY unattributed_open_pipeline DESC
