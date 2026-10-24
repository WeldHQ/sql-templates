-- analytics.cargoson.carrier_costs_by_month
-- BI-facing contract over the core model. See analytics/shipments.sql for why
-- this layer exists even when it is a passthrough.

SELECT * FROM {{core.cargoson.carrier_costs_by_month}}
