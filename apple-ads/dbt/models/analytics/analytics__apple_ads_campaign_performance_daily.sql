-- analytics__apple_ads_campaign_performance_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_apple_ads__campaign_performance_daily') }}
