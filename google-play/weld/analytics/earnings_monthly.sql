-- analytics.google_play.earnings_monthly
-- BI-facing contract over the core model. See the README for why this layer exists
-- even when it is a passthrough.

SELECT * FROM {{core.google_play.earnings_monthly}}
