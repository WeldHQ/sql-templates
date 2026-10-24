-- analytics__launchdarkly_flag_health_by_project
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_launchdarkly__flag_health_by_project') }}
