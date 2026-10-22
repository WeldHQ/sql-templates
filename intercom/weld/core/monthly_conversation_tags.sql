-- core.intercom.monthly_conversation_tags
-- Monthly Tags By Conversation. This SQL template extracts monthly tags by
-- conversation from the Intercom integration. It uses a common table expression
-- (CTE) to join the conversation and conversation_tag tables, and then retrieves
-- the month, tag name, and tag count for each conversation. The results are grouped
-- by month and tag name, and ordered by month in descending order.
--
-- From the weld.app template library. Not reconciled against Intercom;
-- check the output against the source before relying on it.

with
MonthlyTags as (
select
conversation_id
, tag_id
, date_trunc(created_at, month) month
from
{{raw.intercom.conversation}} c
left join {{raw.intercom.conversation_tag}} t on c.id = t.conversation_id
)
select
mt.month
, t.name as tag_name
, count(mt.conversation_id) as tag_count
from
MonthlyTags mt
join {{raw.intercom.tag}} t on mt.tag_id = t.id
group by
mt.month
, t.name
order by
mt.month desc
, tag_count desc
