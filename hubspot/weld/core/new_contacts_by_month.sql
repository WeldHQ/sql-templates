-- core.hubspot.new_contacts_by_month
-- New contacts by month. Retrieves the number of new contacts added to HubSpot each
-- month and groups them by month. It uses the date_trunc function to extract the
-- month from the createdAt field and orders the results by month.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
date_trunc(createdAt, month) as month,
count(*) as contacts
from
{{raw.hubspot.contacts}}
group by
month
order by
month
