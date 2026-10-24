-- core.intercom.monthly_conversations_by_team
-- Monthly Conversations By Team. Extracts monthly conversation data by team from
-- the Intercom integration. It selects the month, team ID, team name, and ticket
-- count from the conversation table. It then joins the conversation table with the
-- team table and groups the results by month, team ID, and team name, ordering them
-- by month and ticket count in descending order.
--
-- From the weld.app template library. Not reconciled against Intercom;
-- check the output against the source before relying on it.

select 
    date_trunc(created_at, month) as month
    , team_assignee_id as team_id
    , te.name as team_name
    , count(co.id) as ticket_count
    FROM{{raw.intercom.conversation}} co
    left join {{raw.intercom.team}} te on cast(co.team_assignee_id as string) = te.id
    group by
    month
    , team_id
    , te.name
    order by
    month desc
    , ticket_count desc
