-- analytics__tiktok_ads_ad_group_performance_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_tiktok_ads__ad_group_performance_daily') }}
