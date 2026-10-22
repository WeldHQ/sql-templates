-- analytics__hubspot_conversion_from_contacts_to_deals_by_owner
-- BI-facing contract over the core model. Dashboards bind here so core can
-- change without breaking them. A passthrough on purpose.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_hubspot__conversion_from_contacts_to_deals_by_owner') }}
