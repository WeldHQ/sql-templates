-- core.klaviyo.events_flow_campaign_report
-- Events Flow Campaign Report. Retrieves data from the Klaviyo integration to
-- generate an Events Flow Campaign Report. It combines information from the events,
-- campaign, and flow tables to provide details such as event timestamps, event
-- names, custom properties, Klaviyo properties, metric IDs, campaign IDs, person
-- IDs, flow IDs, attributed event IDs, message IDs, send cohorts, send timestamps,
-- order IDs, flow names, flow statuses, campaign subjects, and campaign sent
-- timestamps. The final result is sorted in descending order based on the event
-- timestamps.
--
-- From the weld.app template library, corrected. Not reconciled against
-- Klaviyo; check the output against the source before relying on it.

with
    events as (
        select
            event_id
          , cast(event_timestamp as date) event_timestamp
          , event_name
          , custom_properties
          , klaviyo_properties
          , metric_id
          , campaign_id
          , person_id
          , flow_id
          , flow
          , attributed_event_id
          , message_id
          , send_cohort
          , send_ts
          , order_id
        from
            {{staging.klaviyo.email_events}}
    )
  , campaign as (
        select
            id as campaign_id
          , created
          , name
          , status
          , subject
          , sent_at as campaign_sent_at
        from
            {{raw.klaviyo.campaign}}
    )
  , flow as (
        select
            id flow_id
          , name flow_name
          , status as flow_status
          , trigger_type
          , trigger_filter
          , trigger_list_id
          , trigger_list_name
          , customer_filter
          , created flow_created_at
          , updated
        from
            {{raw.klaviyo.flow}}
    )
select
    events.*
  , flow.flow_name
  , flow.flow_status
  , campaign.subject
  , campaign.campaign_sent_at
from
    events
    left join flow on events.flow_id = flow.flow_id
    left join campaign on events.campaign_id = campaign.campaign_id
order by
    event_timestamp desc
