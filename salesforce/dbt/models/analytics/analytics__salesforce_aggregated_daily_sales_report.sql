-- analytics__salesforce_aggregated_daily_sales_report
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_salesforce__aggregated_daily_sales_report') }}
