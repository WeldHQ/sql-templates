-- analytics__calendly_bookings_by_source
-- BI-facing contract over the core model. Dashboards bind here so core can be
-- renamed or re-grained without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_calendly__bookings_by_source') }}
