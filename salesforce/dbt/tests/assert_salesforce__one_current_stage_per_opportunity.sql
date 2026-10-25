-- Each opportunity in the stage history has exactly one running stage entry,
-- and it matches the stage the opportunity is in now.
--
-- More than one current entry means the sequencing broke (two history rows with
-- the same timestamp, say). A current entry that differs from the opportunity's
-- stage means OpportunityHistory is behind the opportunity table, usually
-- because the two streams synced at different times; rerun after the next sync
-- before treating it as a defect.

SELECT
    h.salesforce_org,
    h.opportunity_id,
    COUNTIF(h.is_current_stage)                                    AS current_entries,
    MAX(IF(h.is_current_stage, h.stage_name, NULL))                AS history_stage,
    ANY_VALUE(p.stage_name)                                        AS pipeline_stage
FROM {{ ref('core_salesforce__opportunity_stage_history') }} h
JOIN {{ ref('core_salesforce__opportunity_pipeline') }} p
  ON p.salesforce_org = h.salesforce_org
 AND p.opportunity_id = h.opportunity_id
GROUP BY 1, 2
HAVING COUNTIF(h.is_current_stage) <> 1
    OR MAX(IF(h.is_current_stage, h.stage_name, NULL)) IS DISTINCT FROM ANY_VALUE(p.stage_name)
