-- analytics.chargebee.mrr_by_customer_month
-- BI-facing contract over the core model. See ../README.md for why this layer
-- exists even when it is a passthrough.

SELECT * FROM {{core.chargebee.mrr_by_customer_month}}
