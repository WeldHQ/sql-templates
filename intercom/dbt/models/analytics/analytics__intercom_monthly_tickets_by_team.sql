-- analytics__intercom_monthly_tickets_by_team
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_intercom__monthly_tickets_by_team') }}
