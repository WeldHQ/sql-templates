-- core.intercom.monthly_conversations_rating
-- Monthly Average Conversations Rating. Extracts the monthly average rating for
-- conversations from the Intercom integration. It selects the truncated month and
-- calculates the average rating for conversations that have a non-null rating
-- value. The results are grouped by month and ordered in descending order.
--
-- From the weld.app template library. Not reconciled against Intercom;
-- check the output against the source before relying on it.

select
    date_trunc(conversation_rating_created_at, month) as month
  , avg(conversation_rating_value) as average_rating
from
    {{raw.intercom.conversation}}
where
    conversation_rating_value is not null
group by
    month
order by
    month desc
