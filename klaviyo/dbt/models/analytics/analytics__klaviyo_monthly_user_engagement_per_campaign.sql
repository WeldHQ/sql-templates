-- analytics__klaviyo_monthly_user_engagement_per_campaign
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_klaviyo__monthly_user_engagement_per_campaign') }}
