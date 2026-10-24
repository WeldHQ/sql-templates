-- core.hubspot.closed_won_deals_by_owner
-- Closed won deals by owner. Retrieves the number of closed won deals by owner from
-- HubSpot and orders them in descending order based on the number of deals.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as deal_owner,
count(*) as number_of_deals
from
{{raw.hubspot.deals}} as deals
left join {{raw.hubspot.owners}} as owners on cast(owners.id as int) = deals.properties_hubspot_owner_id
where
properties_dealstage = 'closedwon'
group by
deal_owner
order by
number_of_deals desc
