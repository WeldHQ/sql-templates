-- analytics__gorgias_ticket_volume_by_day
-- BI-facing contract over the core model. See analytics/ticket_lifecycle.sql for
-- why this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_gorgias__ticket_volume_by_day') }}
