-- core_hubspot__closed_lost_deals_by_owner
-- Closed lost deals by owner. Retrieves the number of closed lost deals by owner
-- from HubSpot and orders them by the highest number of deals. It uses a left join
-- to match the owner ID from the deals table to the owners table and concatenates
-- the first and last name of the owner for readability.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as deal_owner,
count(*) as number_of_deals
from
{{ source('hubspot', 'deals') }} as deals
left join {{ source('hubspot', 'owners') }} as owners on cast(owners.id as int) = deals.properties_hubspot_owner_id
where
properties_dealstage = 'closedlost'
group by
deal_owner
order by
number_of_deals desc
