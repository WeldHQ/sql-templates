-- analytics__instagram_business_user_engagement_and_outreach_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_instagram_business__user_engagement_and_outreach_report') }}
