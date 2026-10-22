-- core.hubspot.meetings_by_owner
-- Meetings by owner. Retrieves the number of meetings organized by each owner in
-- HubSpot and displays it alongside their first and last name. It uses a left join
-- to connect the engagements and owners tables and filters the results to only
-- include meetings. The output is grouped by owner.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as owner
, count(*) as meetings
from
{{raw.hubspot.engagements}} as engagements
left join {{raw.hubspot.owners}} as owners on cast(owners.id as integer) = engagements.ownerId
where
type = 'MEETING'
group by owner
