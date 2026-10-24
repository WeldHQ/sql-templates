-- core_hubspot__calls_by_owner
-- Calls by owner. Retrieves the number of calls made by each owner in HubSpot and
-- displays it alongside their first and last name. It uses a left join to connect
-- the engagements and owners tables and filters the results to only include calls.
-- The output is grouped by owner.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as owner
, count(*) as calls
from
{{ source('hubspot', 'engagements') }} as engagements
left join {{ source('hubspot', 'owners') }} as owners on cast(owners.id as integer) = engagements.ownerId
where
type = 'CALL'
group by owner
