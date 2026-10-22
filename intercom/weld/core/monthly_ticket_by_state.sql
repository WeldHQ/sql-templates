-- core.intercom.monthly_ticket_by_state
-- Count of Tickets By State. Extracts the count of tickets grouped by month and
-- ticket state from the Intercom integration. It uses the `date_trunc` function to
-- truncate the `created_at` column to the month level. The result is then ordered
-- by month in descending order, followed by the ticket count in descending order.
--
-- From the weld.app template library. Not reconciled against Intercom;
-- check the output against the source before relying on it.

select
    date_trunc(created_at, month) month
  , ticket_state
  , count(id) as ticket_count
from
    {{raw.intercom.ticket}}
group by
    month
  , ticket_state
order by
    month desc
  , ticket_count desc
