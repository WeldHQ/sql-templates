-- analytics.shiphero.order_fulfillment
-- BI-facing contract over the core model. See analytics/fulfillment_by_day.sql for
-- why this layer exists even when it is a passthrough.

SELECT * FROM {{core.shiphero.order_fulfillment}}
