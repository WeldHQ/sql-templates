-- staging.klaviyo.email_events
-- Email Events. Retrieves various event details from the Klaviyo integration,
-- including the event ID, timestamp, event name, custom properties, Klaviyo
-- properties, UUID, person ID, metric ID, campaign ID, flow ID, flow, attributed
-- event ID, message ID, send cohort, send timestamp, and order ID (if the event
-- name is "Placed Order"). The results are ordered by the event timestamp in
-- descending order.
--
-- From the weld.app template library. Not reconciled against Klaviyo;
-- check the output against the source before relying on it.

select
    id as event_id
  , timestamp as event_timestamp
  , event_name
  , custom_properties
  , klaviyo_properties
  , uuid
  , person_id
  , metric_id
  , campaign_id
  , flow_id
  , json_extract_scalar(klaviyo_properties, '$.flow') as flow
  , json_extract_scalar(
        replace(klaviyo_properties, '$', '')
      , "$['attribution'].attributed_event_id"
    ) as attributed_event_id
  , json_extract_scalar(replace(klaviyo_properties, '$', ''), '$.message') as message_id
  , json_extract_scalar(
        replace(klaviyo_properties, '$', '')
      , '$._cohortmessage_send_cohort'
    ) as send_cohort
  , json_extract_scalar(
        replace(klaviyo_properties, '$', '')
      , "$['attribution'].send_ts"
    ) as send_ts
  , case
        when event_name like 'Placed Order' then json_extract_scalar(klaviyo_properties, '$.event_id')
    end as order_id
from
    {{raw.klaviyo_import.event}}
order by
    event_timestamp desc
