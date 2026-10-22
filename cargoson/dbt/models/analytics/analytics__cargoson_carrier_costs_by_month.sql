-- analytics__cargoson_carrier_costs_by_month
-- BI-facing contract over the core model. See analytics/shipments.sql for why
-- this layer exists even when it is a passthrough.

{{ config(materialized='view') }}

SELECT * FROM {{ ref('core_cargoson__carrier_costs_by_month') }}
