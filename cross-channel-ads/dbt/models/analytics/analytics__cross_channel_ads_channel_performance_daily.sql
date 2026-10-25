-- analytics__cross_channel_ads_channel_performance_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_cross_channel_ads__channel_performance_daily') }}
