-- analytics.chargebee.billing_by_month
-- BI-facing contract over the core model. See ../README.md for why this layer
-- exists even when it is a passthrough.

SELECT * FROM {{core.chargebee.billing_by_month}}
