-- analytics__zendesk_response_times_by_month
-- BI-facing contract over the core model. See analytics/ticket_lifecycle.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_zendesk__response_times_by_month') }}
