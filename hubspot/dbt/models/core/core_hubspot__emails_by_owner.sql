-- core_hubspot__emails_by_owner
-- Emails by owner. Retrieves the number of emails sent by each owner in HubSpot by
-- joining the engagements and owners tables and grouping the results by owner.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as owner
, count(*) as emails
from
{{ source('hubspot', 'engagements') }} as engagements
left join {{ source('hubspot', 'owners') }} as owners on cast(owners.id as integer) = engagements.ownerId
where
type = 'EMAIL'
group by owner
