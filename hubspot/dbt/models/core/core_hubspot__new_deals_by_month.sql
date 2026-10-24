-- core_hubspot__new_deals_by_month
-- New deals by month. Retrieves the number of new deals created each month from
-- HubSpot and organizes them by month.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
date_trunc(createdAt, month) as month,
count(*) as deals
from
{{ source('hubspot', 'deals') }}
group by
month
order by
month
