-- analytics__launchdarkly_context_activity
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_launchdarkly__context_activity') }}
