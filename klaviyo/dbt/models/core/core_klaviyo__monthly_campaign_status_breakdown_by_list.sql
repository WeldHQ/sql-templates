-- core_klaviyo__monthly_campaign_status_breakdown_by_list
-- Monthly Campaign Status Breakdown by List. Generates a monthly breakdown of
-- campaign status for a specific integration with Klaviyo. It retrieves the number
-- of campaigns, the number of campaigns sent, the number of campaigns in draft and
-- scheduled status, as well as other campaign statuses if needed. Additionally, it
-- includes the list name, the number of lists used, and the last sent date. The
-- results are grouped by campaign month, list name, and template name, and ordered
-- in descending order of the campaign month.
--
-- From the weld.app template library. Not reconciled against Klaviyo;
-- check the output against the source before relying on it.

select
    date_trunc(c.created, month) as campaign_month
  , count(distinct c.id) as number_of_campaigns
  , sum(
        case
            when c.status = 'sent' then 1
            else 0
        end
    ) as sent_campaigns
  , sum(
        case
            when c.status = 'draft' then 1
            else 0
        end
    ) as draft_campaigns
  , sum(
        case
            when c.status = 'scheduled' then 1
            else 0
        end
    ) as scheduled_campaigns
  , -- Add other campaign statuses as needed
    l.list_name as list_name
  , count(distinct cl.list_id) as number_of_lists_used
  , max(c.sent_at) as last_sent_date
from
    {{ source('klaviyo', 'campaign') }} c
    left join {{ source('klaviyo', 'campaign_list') }} cl on c.id = cl.campaign_id
    left join {{ source('klaviyo', 'list') }} l on cl.list_id = l.id
    left join {{ source('klaviyo', 'email_template') }} t on c.template_id = t.id
group by
    campaign_month
  , l.list_name
  , t.name
order by
    campaign_month desc
