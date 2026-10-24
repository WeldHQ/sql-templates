-- analytics__klaviyo_monthly_campaign_status_breakdown_by_list
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_klaviyo__monthly_campaign_status_breakdown_by_list') }}
