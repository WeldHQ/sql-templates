-- analytics.claimlane.b2b_claims_by_month
-- BI-facing contract over the core model. See analytics/b2c_claims_by_month.sql
-- for why this layer exists even when it is a passthrough.

SELECT * FROM {{core.claimlane.b2b_claims_by_month}}
