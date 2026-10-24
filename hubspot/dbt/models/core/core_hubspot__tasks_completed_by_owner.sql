-- core_hubspot__tasks_completed_by_owner
-- Tasks completed by owner. Retrieves the number of completed tasks for each owner
-- in HubSpot, using a left join between the engagements and owners tables. The
-- result includes the owner's first and last name, as well as the count of
-- completed tasks.
--
-- From the weld.app template library, corrected. Not reconciled against
-- HubSpot; check the output against the source before relying on it.

select
concat(owners.firstName, ' ', owners.lastName) as owner
, count(*) as tasks_completed
from
{{ source('hubspot', 'engagements') }} as engagements
left join {{ source('hubspot', 'owners') }} as owners on cast(owners.id as integer) = engagements.ownerId
where
type = 'TASK' and
json_value(metadata, '$.status') = 'COMPLETED'
group by owner
