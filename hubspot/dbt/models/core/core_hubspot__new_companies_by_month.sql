-- core_hubspot__new_companies_by_month
-- New companies by month. Retrieves a list of new companies created each month from
-- the HubSpot integration and groups them by month. The results are ordered by
-- month.
--
-- From the weld.app template library. Not reconciled against HubSpot;
-- check the output against the source before relying on it.

select
    date_trunc(createdAt, month) as month,
    count(*) as companies
from
    {{ source('hubspot', 'companies') }}
group by
    month
order by
    month
