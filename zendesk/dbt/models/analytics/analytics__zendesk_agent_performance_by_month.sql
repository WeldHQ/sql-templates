-- analytics__zendesk_agent_performance_by_month
-- BI-facing contract over the core model. See analytics/ticket_lifecycle.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_zendesk__agent_performance_by_month') }}
