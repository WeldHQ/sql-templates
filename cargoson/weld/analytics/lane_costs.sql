-- analytics.cargoson.lane_costs
-- BI-facing contract over the core model. See analytics/shipments.sql for why
-- this layer exists even when it is a passthrough.

SELECT * FROM {{core.cargoson.lane_costs}}
