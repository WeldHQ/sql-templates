-- Every deal in deal_stage_history has exactly one current stage, and no stage
-- entry ends before it starts.
--
-- Both break if the history has two dealstage changes on the same timestamp, which
-- makes the LEAD() ordering ambiguous and time in stage meaningless.

SELECT hubspot_portal, deal_id, 'current_stage_count' AS problem
FROM {{ ref('core_hubspot_v2__deal_stage_history') }}
GROUP BY 1, 2
HAVING COUNTIF(is_current_stage) <> 1

UNION ALL

SELECT hubspot_portal, deal_id, 'exits_before_entering'
FROM {{ ref('core_hubspot_v2__deal_stage_history') }}
WHERE exited_at <= entered_at
