-- analytics__clickup_user_activity_and_performance_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_clickup__user_activity_and_performance_report') }}
