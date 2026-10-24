-- core_hubspot__deals_by_deal_stage
-- Deals by deal stage. Retrieves the number of deals in each stage of the sales
-- pipeline from HubSpot and groups them by their respective stage labels.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
pipeline_stage.label as deal_stage
, count(*) as number_of_deals
from
{{ source('hubspot', 'deals') }} as deals
left join {{ source('hubspot', 'pipeline_stage') }} as pipeline_stage on pipeline_stage.stage_id = properties_dealstage
group by
pipeline_stage.label
