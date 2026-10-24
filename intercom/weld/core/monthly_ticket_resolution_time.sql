-- core.intercom.monthly_ticket_resolution_time
-- Monthly Ticket Resolution Time. Extracts the monthly ticket resolution time for a
-- specific integration (intercom). It selects the month, team ID, team name, and
-- average resolution time in days. It joins the ticket and team tables, filters for
-- resolved tickets, groups the results by month and team, and sorts them in
-- descending order by month and ascending order by average resolution time.
--
-- From the weld.app template library. Not reconciled against Intercom;
-- check the output against the source before relying on it.

select
    date_trunc(t.created_at, month) as month
  , t.team_assignee_id as team_id
  , te.name as team_name
  , avg(date_diff(t.updated_at, t.created_at, day)) as avg_resolution_time_days 
  FROM{{raw.intercom.ticket}} t
    left join {{raw.intercom.team}} te on cast(t.team_assignee_id as string) = te.id
where
    ticket_state = 'resolved'
group by
    month
  , team_id
  , name
  ORDER by month desc
  , avg_resolution_time_days asc
