-- analytics__instagram_business_engagement_metric_analysis
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_instagram_business__engagement_metric_analysis') }}
