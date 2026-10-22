-- core_hubspot__closed_won_deals_amount_by_owner
-- Closed won deals amount by owner. Retrieves the total amount of closed won deals
-- for each owner in HubSpot and orders them in descending order.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as deal_owner,
sum(properties_amount) as amount
from
{{ source('hubspot', 'deals') }} as deals
left join {{ source('hubspot', 'owners') }} as owners on cast(owners.id as int) = deals.properties_hubspot_owner_id
where
properties_dealstage = 'closedwon'
group by
deal_owner
order by
amount desc
