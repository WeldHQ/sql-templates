-- analytics__linkedin_pages_follower_growth_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_linkedin_pages__follower_growth_daily') }}
