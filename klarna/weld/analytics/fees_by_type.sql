-- analytics.klarna.fees_by_type
-- BI-facing contract over the core model. See analytics/payout_reconciliation.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.klarna.fees_by_type}}
