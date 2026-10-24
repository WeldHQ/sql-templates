-- stg_klaviyo__email_events
-- Email Events. Retrieves various event details from the Klaviyo integration,
-- including the event ID, timestamp, event name, custom properties, Klaviyo
-- properties, UUID, person ID, metric ID, campaign ID, flow ID, flow, attributed
-- event ID, message ID, send cohort and order ID (if the event name is "Placed
-- Order"). The results are ordered by the event timestamp in descending order.
--
-- The event table holds the metric id, not the event name; the name comes from
-- the metric table. person_id is the event's Klaviyo profile id. campaign_id and
-- flow_id come from Klaviyo's attribution data for the event and are null for
-- events with no attribution.
--
-- Klaviyo prefixes its own property keys with $ ($flow, $message, $event_id).
-- Each lookup strips the $ from the JSON first so plain paths can reach them.
--
-- From the weld.app template library, corrected and ported to the current synced
-- schema. Not reconciled against Klaviyo; check the output against the source
-- before relying on it.

select
    e.id as event_id
  , e.timestamp as event_timestamp
  , m.name as event_name
  , e.custom_properties
  , e.klaviyo_properties
  , e.uuid
  , e.profile_id as person_id
  , e.metric_id
  , e.campaign_id
  , e.flow_id
  , json_extract_scalar(replace(e.klaviyo_properties, '$', ''), '$.flow') as flow
  , json_extract_scalar(
        replace(e.klaviyo_properties, '$', '')
      , "$['attribution'].attributed_event_id"
    ) as attributed_event_id
  , json_extract_scalar(replace(e.klaviyo_properties, '$', ''), '$.message') as message_id
  , json_extract_scalar(
        replace(e.klaviyo_properties, '$', '')
      , '$._cohortmessage_send_cohort'
    ) as send_cohort
  , case
        when m.name = 'Placed Order' then json_extract_scalar(replace(e.klaviyo_properties, '$', ''), '$.event_id')
    end as order_id
from
    {{ source('klaviyo', 'event') }} e
    left join {{ source('klaviyo', 'metric') }} m on m.id = e.metric_id
order by
    event_timestamp desc
