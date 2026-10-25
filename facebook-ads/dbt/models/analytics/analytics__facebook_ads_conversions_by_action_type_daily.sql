-- analytics__facebook_ads_conversions_by_action_type_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_facebook_ads__conversions_by_action_type_daily') }}
