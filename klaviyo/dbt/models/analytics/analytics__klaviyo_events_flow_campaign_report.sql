-- analytics__klaviyo_events_flow_campaign_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_klaviyo__events_flow_campaign_report') }}
