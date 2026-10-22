-- analytics__clickup_monthly_time_tracking_and_billing_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_clickup__monthly_time_tracking_and_billing_report') }}
