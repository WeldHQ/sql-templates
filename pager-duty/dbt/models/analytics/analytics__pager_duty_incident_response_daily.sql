-- analytics__pager_duty_incident_response_daily
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_pager_duty__incident_response_daily') }}
