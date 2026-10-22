-- analytics__google_analytics_4_channel_traffic_overview
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_google_analytics_4__channel_traffic_overview') }}
