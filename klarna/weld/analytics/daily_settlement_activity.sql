-- analytics.klarna.daily_settlement_activity
-- BI-facing contract over the core model. See analytics/payout_reconciliation.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.klarna.daily_settlement_activity}}
