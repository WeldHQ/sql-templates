-- analytics__google_analytics_4_user_activity_overview
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_google_analytics_4__user_activity_overview') }}
