-- core.intercom.monthly_tickets_by_team
-- Monthly Tickets By Team. Extracts monthly ticket data for each team, including
-- the team ID, team name, and the count of tickets. It uses the Intercom
-- integration and joins the ticket and team tables based on the team assignee ID.
-- The results are grouped by month, team ID, and team name, and ordered by month
-- and ticket count in descending order.
--
-- From the weld.app template library. Not reconciled against Intercom;
-- check the output against the source before relying on it.

select
    date_trunc(created_at, month) as month
  , team_assignee_id as team_id
  , te.name as team_name
  , count(ti.id) as ticket_count
from
    {{raw.intercom.ticket}} ti
    left join {{raw.intercom.team}} te on ti.team_assignee_id = te.id
group by
    month
  , team_id
  , te.name
order by
    month desc
  , ticket_count desc
