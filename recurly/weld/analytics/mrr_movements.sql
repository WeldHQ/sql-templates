-- analytics.recurly.mrr_movements
-- BI-facing contract over the core model. See ../README.md for why this layer
-- exists even when it is a passthrough.

SELECT * FROM {{core.recurly.mrr_movements}}
