-- One row per deal and stage entry in deal_stage_history.
--
-- Stage labels are looked up by stage id across every deal pipeline. If the same
-- stage id ever turned up in two pipelines, that lookup would turn one stage
-- entry into two rows and double every time-in-stage figure. This is the guard.

SELECT hubspot_portal, deal_id, entry_number, COUNT(*) AS row_count
FROM {{ ref('core_hubspot_v2__deal_stage_history') }}
GROUP BY 1, 2, 3
HAVING COUNT(*) > 1
