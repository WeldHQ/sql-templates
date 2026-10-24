-- core_klaviyo__monthly_campaign_status_breakdown_by_list
-- Monthly Campaign Status Breakdown by List. Generates a monthly breakdown of
-- campaign status for a specific integration with Klaviyo. It retrieves the number
-- of campaigns, the number of campaigns sent, the number of campaigns in draft and
-- scheduled status, as well as other campaign statuses if needed. Additionally, it
-- includes the list name, the number of lists used, and the last send time. The
-- results are grouped by campaign month and list name, and ordered in descending
-- order of the campaign month.
--
-- A campaign's audiences are the lists and segments in
-- campaign_audiences_included. list_name is the list's name, or the segment's
-- name when the audience is a segment. A campaign sent to several audiences is
-- counted once under each. Statuses are compared in lower case.
--
-- From the weld.app template library, ported to the current synced schema. Not
-- reconciled against Klaviyo; check the output against the source before relying
-- on it.

select
    date_trunc(date(c.created_at), month) as campaign_month
  , count(distinct c.id) as number_of_campaigns
  , count(distinct case when lower(c.status) = 'sent' then c.id end) as sent_campaigns
  , count(distinct case when lower(c.status) = 'draft' then c.id end) as draft_campaigns
  , count(distinct case when lower(c.status) = 'scheduled' then c.id end) as scheduled_campaigns
  , -- Add other campaign statuses as needed
    coalesce(l.name, s.name) as list_name
  , count(distinct a.value) as number_of_lists_used
  , max(c.send_time) as last_sent_date
from
    {{ source('klaviyo', 'campaign') }} c
    left join {{ source('klaviyo', 'campaign_audiences_included') }} a on c.id = a.campaign_id
    left join {{ source('klaviyo', 'list') }} l on a.value = l.id
    left join {{ source('klaviyo', 'segment') }} s on a.value = s.id
group by
    campaign_month
  , list_name
order by
    campaign_month desc
