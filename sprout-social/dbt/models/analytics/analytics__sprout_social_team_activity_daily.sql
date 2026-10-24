-- analytics__sprout_social_team_activity_daily
-- BI-facing contract over the core model. Deliberately thin: dashboards bind to
-- this name, so core can be refactored without breaking anything downstream.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_sprout_social__team_activity_daily') }}
