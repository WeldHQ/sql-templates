-- analytics__hubspot_meetings_by_owner
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot__meetings_by_owner') }}
