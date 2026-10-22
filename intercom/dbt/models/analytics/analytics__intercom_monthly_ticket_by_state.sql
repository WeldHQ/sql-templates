-- analytics__intercom_monthly_ticket_by_state
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_intercom__monthly_ticket_by_state') }}
